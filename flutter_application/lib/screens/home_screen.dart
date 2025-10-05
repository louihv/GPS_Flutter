import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart' as myAuth;
import '../constants/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Position? _location;
  LocationPermission? _permissionStatus;  // Fixed: Use LocationPermission?
  bool _searchBarVisible = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _suggestions = [];
  String _mapType = 'roadmap';
  bool _showWeather = false;
  late AnimationController _searchAnimController;
  late Animation<double> _searchAnim;
  final WebViewController _webViewController = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(ThemeConstants.lightBg);
  final Map<String, Map<String, dynamic>> _weatherCache = {};
  bool _isLoading = true;
  bool _webViewLoaded = false;
  String? _contactPerson;
  String? _firstName;
  String? _lastName;
  final bool _hasShownModal = false;

  // Placeholder API key - replace with yours
  static const String _openWeatherApiKey = 'YOUR_OPEN_WEATHER_API_KEY';  // From RN code

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _searchAnimController, curve: Curves.ease),
    );
    // Fixed: Add JS channel in initState (after controller setup)
    _webViewController.addJavaScriptChannel(
      'ReactNativeWebView',  // Matches JS postMessage target
      onMessageReceived: (JavaScriptMessage message) {
        _handleWebViewMessage(message.message);
      },
    );
    _checkPermissionStatus();
    _fetchUserData();
  }

  @override
  void dispose() {
    _searchAnimController.dispose();
    super.dispose();
  }

  // Map Styles CSS (copied from RN)
  String get _mapStyles => '''
    body { margin: 0; }
    #map { height: 100vh; width: 100%; }
    .overlay-container { position: absolute; top: 100px; left: 10px; right: 10px; z-index: 1000; }
    .search-wrapper { position: relative; }
    .search-container { 
      display: flex; 
      align-items: center; 
      background: #FFF9F0; 
      box-shadow: 0 2px 4px rgba(0,0,0,0.2); 
      transition: all 0.3s ease; 
      overflow: hidden;
      border: solid 1px #14aebb;
    }
    .search-container.closed { 
      width: 45px; 
      height: 45px; 
      border-radius: 100%; 
      padding-left: 1px; 
    }
    .search-container.open { 
      width: 100%; 
      height: 45px; 
      border-radius: 30px; 
      padding-left: 0; 
    }
    .search-icon {
      display: block;       
      text-align: center;    
      padding: 15px 12px;
      font-size: 25px;
      cursor: pointer;
      margin-top: 5px;
      color: #14aebb;
    }
    .search-input-container { 
      flex: 1; 
      transition: opacity 0.3s ease, transform 0.3s ease; 
      background: transparent;
    }
    .search-input-container.hidden { 
      opacity: 0; 
      transform: translateX(20px); 
    }
    .search-input-container.visible { 
      opacity: 1; 
      transform: translateX(0); 
    }
    .search-input { 
      flex: 1; 
      padding: 8px; 
      font-size: 14px; 
      border: none; 
      outline: none; 
      background: transparent;
      font-family: 'Poppins', sans-serif; 
      color: #000; 
    }
    .search-input::placeholder { 
      color: #777; 
    }
    .suggestions-container { 
      position: absolute; 
      top: 50px; 
      left: 0; 
      right: 0; 
      background: white; 
      border: 1px solid #FFF9F0; 
      max-height: 200px; 
      overflow-y: auto; 
      z-index: 1000; 
      box-shadow: 0 2px 4px rgba(0,0,0,0.2); 
    }
    .suggestion-item { 
      padding: 10px; 
      border-bottom: 1px solid #FFF9F0; 
      cursor: pointer; 
    }
    .suggestion-item:hover { 
      background: #FFF9F0; 
    }
    .return-button { 
      position: absolute; 
      top: 0; 
      right: -1px; 
      background: #14aebb; 
      padding: 12px;
      border: none;
      border-radius: 25px; 
      box-shadow: 0 2px 4px rgba(0,0,0,0.2); 
      z-index: 1000; 
      display: flex;              
      align-items: center;  
      justify-content: center;      
    }
    
    .map-type-buttons-container { 
      position: absolute; 
      top: 180px; 
      left: 10px; 
      z-index: 999; 
      display: flex;           
      flex-direction: column;    
      gap: 8px;  
    }
    
    .bayanihan-infowindow {
      font-family: 'Poppins', sans-serif;
      color: #333;
      animation: slideIn 0.3s ease-out;
    }
    .bayanihan-infowindow h3 {
      margin: 0 0 10px;
      color: #007BFF;
      font-size: 18px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .bayanihan-infowindow p {
      margin: 5px 0;
      font-size: 14px;
    }
    @keyframes slideIn {
      0% { transform: translateY(10px); opacity: 0; }
      100% { transform: translateY(0); opacity: 1; }
    }
    .custom-marker {
      font-size: 24px;
      text-align: center;
    }
  ''';

  // Full Map HTML (adapted from RN - interpolated for location)
  String get _mapHtml {
    if (_permissionStatus != LocationPermission.always && _permissionStatus != LocationPermission.whileInUse || _location == null) {
      return '';  // No map if no location
    }
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <link href='https://cdn.boxicons.com/fonts/basic/boxicons.min.css' rel='stylesheet'>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Poppins:ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;0,800;0,900;1,100;1,200;1,300;1,400;1,500;1,600;1,700;1,800;1,900&display=swap" rel="stylesheet">
      <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
      <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
      <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>
      <style>$_mapStyles</style>
      <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js"></script>
      <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-database-compat.js"></script>
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    </head>
    <body>
      <div class="overlay-container">
        <div class="search-wrapper">
          <div id="searchContainer" class="search-container closed">
            <span id="searchIcon" class="search-icon"><i class='bxr bx-search'></i></span>
            <div id="searchInputContainer" class="search-input-container hidden">
              <input id="searchInput" class="search-input" type="text" placeholder="Search for a location" />
            </div>
          </div>
          <div id="suggestions" class="suggestions-container"></div>
          <button id="returnButton" class="return-button">
            <span class="material-icons" style="font-size:28px; color:#fff;">my_location</span>
          </button>          
        </div>
      </div>
      <div id="map"></div>
      <script>
        const firebaseConfig = {
          apiKey: "AIzaSyBkmXOJvnlBtzkjNyR6wyd9BgGM0BhN0L8",
          authDomain: "bayanihan-new-472410.firebaseapp.com",
          projectId: "bayanihan-new-472410",
          storageBucket: "bayanihan-new-472410.firebasestorage.app",
          messagingSenderId: "995982574131",
          appId: "1:995982574131:web:3d45e358fad330c276d946",
          measurementId: "G-CEVPTQZM9C",
          databaseURL: "https://bayanihan-new-472410-default-rtdb.asia-southeast1.firebasedatabase.app/"
        };
        firebase.initializeApp(firebaseConfig);
        const database = firebase.database();
        let map, userMarker, weatherMarker, currentLayer;
        let activationMarkers = [];
        let nonActivationMarkers = [];
        let singlePopup;
        let weatherCache = new Map();
        let searchBarVisible = false;
        let mapType = 'roadmap';  // Fixed: Declare mapType
        const OPEN_WEATHER_API_KEY = "$_openWeatherApiKey";  // Dart-interpolated

        function initMap() {
          try {
            const userLocation = L.latLng(${_location!.latitude}, ${_location!.longitude});
            map = L.map('map', {
              center: userLocation,
              zoom: 16,
              zoomControl: false,
              attributionControl: false,
              doubleClickZoom: false,
              boxZoom: false,
              keyboard: false,
            });
            currentLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
              attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
              maxZoom: 18,
            }).addTo(map);
            userMarker = L.marker(userLocation, {
              title: "Your Location",
              icon: L.icon({
                iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
                iconSize: [25, 41],
                iconAnchor: [12, 41],
                popupAnchor: [1, -34],
                shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
                shadowSize: [41, 41],
              }),
            }).addTo(map);
            nonActivationMarkers.push(userMarker);
            fetch('https://nominatim.openstreetmap.org/reverse?format=json&lat=${_location!.latitude}&lon=${_location!.longitude}', {
              headers: { 'User-Agent': 'BayanihanApp/1.0 (your.email@example.com)' },
            })
              .then(response => response.json())
              .then(data => {
                const infoContent = data.display_name || `Lat: ${_location!.latitude}, Lng: ${_location!.longitude}`;
                userMarker.bindPopup(infoContent).openPopup();
              })
              .catch(error => {
                console.error("Reverse geocoding error:", error);
                userMarker.bindPopup(`Lat: ${_location!.latitude}, Lng: ${_location!.longitude}`).openPopup();
              });
            loadActivations();
            loadWeather(${_location!.latitude}, ${_location!.longitude}, true);
            // ... (rest of initMap from RN - click handler, search event listeners, map type buttons, weather btn)
            map.on('click', async (e) => {
              clearNonActivationMarkers();
              const marker = L.marker(e.latlng, { title: "Pinned Location" }).addTo(map);
              nonActivationMarkers.push(marker);
              try {
                const response = await fetch('https://nominatim.openstreetmap.org/reverse?format=json&lat=' + e.latlng.lat + '&lon=' + e.latlng.lng, {
                  headers: { 'User-Agent': 'BayanihanApp/1.0 (your.email@example.com)' },
                });
                const data = await response.json();
                const infoContent = data.display_name || `Lat: \${e.latlng.lat}, Lng: \${e.latlng.lng}`;
                marker.bindPopup(infoContent).openPopup();
                await loadWeather(e.latlng.lat, e.latlng.lng, false);
              } catch (error) {
                console.error("Reverse geocoding error:", error);
                marker.bindPopup(`Lat: \${e.latlng.lat}, Lng: \${e.latlng.lng}`).openPopup();
              }
              map.setView(e.latlng, 16);
            });
            document.getElementById('searchIcon').addEventListener('click', function () {
              searchBarVisible = !searchBarVisible;
              document.getElementById('searchContainer').classList[searchBarVisible ? 'remove' : 'add']('closed');
              document.getElementById('searchContainer').classList[searchBarVisible ? 'add' : 'remove']('open');
              document.getElementById('searchInputContainer').classList[searchBarVisible ? 'remove' : 'add']('hidden');
              document.getElementById('searchInputContainer').classList[searchBarVisible ? 'add' : 'remove']('visible');
              if (searchBarVisible) {
                document.getElementById('searchInput').focus();
              } else {
                document.getElementById('searchInput').value = '';
                document.getElementById('suggestions').style.display = 'none';
              }
              window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'toggleSearch', visible: searchBarVisible }));
            });
            window.searchInputHandler = async function (e) {
              const query = e.target.value;
              if (query.length < 3) {
                document.getElementById('suggestions').style.display = 'none';
                return;
              }
              try {
                const response = await fetch(
                  'https://nominatim.openstreetmap.org/search?format=json&q=' + encodeURIComponent(query) + '&countrycodes=PH&limit=5', {
                  headers: { 'User-Agent': 'BayanihanApp/1.0 (your.email@example.com)' }
                });
                const results = await response.json();
                const suggestionsDiv = document.getElementById('suggestions');
                suggestionsDiv.innerHTML = '';
                results.forEach(result => {
                  const div = document.createElement('div');
                  div.className = 'suggestion-item';
                  div.textContent = result.display_name;
                  div.dataset.placeId = result.place_id;
                  div.onclick = function () {
                    map.setView([result.lat, result.lon], 16);
                    clearNonActivationMarkers();
                    const marker = L.marker([result.lat, result.lon], {
                      title: result.display_name,
                    }).addTo(map);
                    nonActivationMarkers.push(marker);
                    marker.bindPopup(result.display_name).openPopup();
                    document.getElementById('searchInput').value = result.display_name;
                    suggestionsDiv.style.display = 'none';
                    window.ReactNativeWebView.postMessage(JSON.stringify({
                      action: 'selectSuggestion',
                      latitude: result.lat,
                      longitude: result.lon,
                      formattedAddress: result.display_name
                    }));
                  };
                  suggestionsDiv.appendChild(div);
                });
                suggestionsDiv.style.display = results.length > 0 ? 'block' : 'none';
              } catch (error) {
                console.error('Search error:', error);
                window.ReactNativeWebView.postMessage(JSON.stringify({
                  action: 'showError',
                  message: 'Failed to fetch suggestions. Please check your internet connection.'
                }));
              }
            };
            document.getElementById('searchInput').addEventListener('input', window.searchInputHandler);
            document.getElementById('returnButton').addEventListener('click', function () {
              window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'requestUserLocation' }));
            });
            // Map type buttons (roadmap/hybrid)
            document.getElementById('roadmapBtn').addEventListener('click', function () {
              if (mapType !== 'roadmap') {
                map.removeLayer(currentLayer);
                currentLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                  attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
                  maxZoom: 18,
                }).addTo(map);
                mapType = 'roadmap';
                document.getElementById('roadmapBtn').classList.add('active');
                document.getElementById('hybridBtn').classList.remove('active');
              }
            });
            document.getElementById('hybridBtn').addEventListener('click', function () {
              if (mapType !== 'hybrid') {
                map.removeLayer(currentLayer);
                currentLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
                  attribution: '&copy; <a href="https://www.esri.com/">Esri</a>',
                  maxZoom: 18,
                }).addTo(map);
                mapType = 'hybrid';
                document.getElementById('hybridBtn').classList.add('active');
                document.getElementById('roadmapBtn').classList.remove('active');
              }
            });
            document.getElementById('weatherBtn').addEventListener('click', function () {
              window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'toggleWeather' }));
            });
          } catch (error) {
            console.error("Map initialization error:", error);
            window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'error', message: 'Map initialization failed: ' + error.message }));
          }
        }

        function loadActivations() {
          try {
            const activationsRef = database.ref("activations/currentActivations").orderByChild("status").equalTo("active");
            activationsRef.on("value", (snapshot) => {
              activationMarkers.forEach(marker => marker.remove());
              activationMarkers = [];
              const activations = snapshot.val();
              if (!activations) {
                window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'info', message: 'No active activations found.' }));
                return;
              }
              Object.entries(activations).forEach(([key, activation]) => {
                if (!activation.address?.latitude || !activation.address?.longitude) return;
                const lat = parseFloat(activation.address.latitude);
                const lng = parseFloat(activation.address.longitude);
                if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) return;
                const position = L.latLng(lat, lng);
                const logoPath = "https://firebasestorage.googleapis.com/v0/b/bayanihan-new-472410.appspot.com/o/AB_logo.png?alt=media";
                const marker = L.marker(position, {
                  title: activation.organization || "Unknown Organization",
                  icon: L.divIcon({
                    html: `<span><i class="bxr bx-community" style="color: #FA3B99; font-size: 50px;"></i></span>`,
                    className: 'custom-marker',
                    iconSize: [30, 30],
                    iconAnchor: [15, 30],
                    popupAnchor: [0, -30],
                  }),
                }).addTo(map);
                activationMarkers.push(marker);
                createPopup(marker, activation, logoPath);
              });
            });
          } catch (error) {
            console.error("Error in loadActivations:", error.message);
            window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'error', message: 'Activation loading failed: ' + error.message }));
          }
        }

        async function loadWeather(lat, lng, isUserLocation) {
          try {
            const cacheKey = `\${lat}_\${lng}`;
            if (weatherCache.has(cacheKey)) {
              createWeatherPopup(lat, lng, weatherCache.get(cacheKey), isUserLocation);
              return;
            }
            const response = await fetch(`https://api.openweathermap.org/data/2.5/weather?lat=\${lat}&lon=\${lng}&appid=\${OPEN_WEATHER_API_KEY}&units=metric`);
            if (!response.ok) throw new Error(`Weather API error: \${response.status}`);
            const weatherData = await response.json();
            weatherCache.set(cacheKey, weatherData);
            createWeatherPopup(lat, lng, weatherData, isUserLocation);
          } catch (error) {
            console.error("Weather fetch error:", error.message);
            window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'error', message: 'Failed to load weather data: ' + error.message }));
          }
        }

        function createWeatherPopup(lat, lng, weatherData, isUserLocation) {
          if (weatherMarker) weatherMarker.remove();
          const condition = weatherData.weather[0].main.toLowerCase();
          const temp = weatherData.main.temp;
          const description = weatherData.weather[0].description;
          const icon = condition.includes("clear") ? "☀️" :
                      condition.includes("rain") || condition.includes("drizzle") || condition.includes("thunderstorm") ? "🌧️" :
                      condition.includes("clouds") ? "☁️" : "🌫️";
          const popupContent = `
            <div class="bayanihan-infowindow">
              <h3 style="color: black; font-family: 'Poppins', sans-serif;">
                <span style="font-size: 24px;">\${icon}</span>
                Weather at \${isUserLocation ? 'Your Location' : 'Selected Location'}
              </h3>
              <p><strong style="color: black; font-weight: bold;">Condition:</strong> \${description}</p>
              <p><strong style="color: black; font-weight: bold;">Temperature:</strong> \${temp}°C</p>
              <p><strong style="color: black; font-weight: bold;">Humidity:</strong> \${weatherData.main.humidity}%</p>
              <p><strong style="color: black; font-weight: bold;">Wind Speed:</strong> \${weatherData.wind.speed} m/s</p>
            </div>
          `;
          weatherMarker = L.marker([lat, lng], {
            title: "Weather",
            icon: L.divIcon({
              html: `<span style="font-size: 24px;">\${icon}</span>`,
              className: 'custom-marker',
              iconSize: [30, 30],
              iconAnchor: [15, 30],
              popupAnchor: [0, -30],
            }),
          });
          weatherMarker.on('click', () => {
            if (singlePopup && singlePopup._source !== weatherMarker) singlePopup.remove();
            singlePopup = L.popup().setContent(popupContent).setLatLng([lat, lng]).openOn(map);
          });
          if ($_showWeather) weatherMarker.addTo(map);
        }

        function createPopup(marker, activation, logoPath) {
          fetch(logoPath)
            .then(response => response.ok ? response.url : null)
            .catch(() => null)
            .then(logoUrl => {
              const content = `
                <div class="bayanihan-infowindow">
                  <h3 style="color: black; font-family: 'Poppins', sans-serif;">\${activation.organization || 'Unknown Organization'}</h3>
                  <p><strong style="color: black; font-weight: bold; font-family: 'Poppins', sans-serif">Area:</strong> <span style="font-family: 'Poppins', sans-serif;">\${activation.areaOfOperation || 'N/A'}</span></p>
                  <p><strong style="color: black; font-weight: bold; font-family: 'Poppins', sans-serif">Calamity:</strong> <span style="font-family: 'Poppins', sans-serif;">\${activation.calamityType || 'N/A'}\${activation.typhoonName ? ` (\${activation.typhoonName})` : ''}</span></p>
                  <p><strong style="color: black; font-weight: bold; font-family: 'Poppins', sans-serif">Status:</strong> <span style="color: #388E3C; font-weight: bold; font-family: 'Poppins', sans-serif;">Active</span></p>
                </div>
              `;
              marker.on('click', () => {
                if (singlePopup && singlePopup._source !== marker) singlePopup.remove();
                singlePopup = L.popup().setContent(content).setLatLng(marker.getLatLng()).openOn(map);
              });
            });
        }

        function clearNonActivationMarkers() {
          nonActivationMarkers.forEach(marker => marker.remove());
          nonActivationMarkers = [];
        }

        window.addEventListener('message', function(event) {
          try {
            const data = JSON.parse(event.data);
            if (data.action === 'updateLocation') {
              const userLocation = L.latLng(data.latitude, data.longitude);
              map.setView(userLocation, 16);
              clearNonActivationMarkers();
              const userMarker = L.marker(userLocation, { /* icon config */ }).addTo(map);
              nonActivationMarkers.push(userMarker);
              userMarker.bindPopup(data.formattedAddress || `Lat: \${data.latitude}, Lng: \${data.longitude}`).openPopup();
            } else if (data.action === 'requestUserLocation') {
              window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'requestUserLocation' }));
            } else if (data.action === 'toggleWeather') {
              if (weatherMarker) weatherMarker[${_showWeather ? 'remove' : 'addTo'}](map);
            } else if (data.action === 'selectSuggestion') {
              setTimeout(() => loadWeather(data.latitude, data.longitude, false), 0);
            }
          } catch (error) {
            console.error('Message parsing error:', error);
          }
        });

        window.initMap = initMap;
        window.clearNonActivationMarkers = clearNonActivationMarkers;
        initMap();
      </script>
    </body>
    </html>
    ''';
  }

  String? _getUserName(myAuth.AuthProvider authProvider) {
    if (authProvider.user == null) return 'Unknown User';
    if (_contactPerson != null) return _contactPerson;
    if (_firstName != null || _lastName != null) return '${_firstName ?? ''} ${_lastName ?? ''}'.trim();
    return 'Unknown User';
  }

  Future<void> _checkPermissionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasShownModal = prefs.getBool('hasShownLocationModal') ?? false;
      final permission = await Geolocator.checkPermission();  // Fixed: Returns LocationPermission
      if (mounted) setState(() => _permissionStatus = permission);
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _location = position;
            if (position.accuracy > 50) {
              Fluttertoast.showToast(msg: 'Your location accuracy is low. The pin may not be precise.');
            }
          });
        }
      } else if (hasShownModal && (permission == LocationPermission.denied || permission == LocationPermission.deniedForever)) {
        if (mounted) setState(() => _permissionStatus = LocationPermission.denied);
        if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
        Fluttertoast.showToast(msg: 'Location access is required to view the map.');
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
      if (mounted) setState(() => _permissionStatus = LocationPermission.denied);
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
      Fluttertoast.showToast(msg: 'Failed to check location permission. Please enable it in Dashboard.');
    } finally {
      if (mounted) setState(() => _isLoading = !_webViewLoaded);
    }
  }

  Future<void> _fetchUserData() async {
    final authProvider = Provider.of<myAuth.AuthProvider>(context, listen: false);
    if (authProvider.user?.uid == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedUserJson = prefs.getString('user_session');
        if (cachedUserJson != null) {
          final cachedUser = jsonDecode(cachedUserJson) as Map<String, dynamic>;
        } else {
          _showErrorModal('Please log in to continue.');
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      } catch (e) {
        debugPrint('Error loading cached user: $e');
        _showErrorModal('Failed to load user data. Please log in again.');
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
    }
    try {
      final db = FirebaseDatabase.instance.ref();  // Fixed: Added import and correct ref
      final userRef = db.child('users/${authProvider.user!.uid}');
      final snapshot = await userRef.get();
      if (snapshot.exists) {
        final userData = snapshot.value as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            _contactPerson = userData?['contactPerson'];
            _firstName = userData?['firstName'];
            _lastName = userData?['lastName'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      // Fallback to authProvider data
    } finally {
      if (mounted) setState(() => _isLoading = !_webViewLoaded);
    }
  }

  Future<void> _handleRetryPermission() async {
    try {
      final permission = await Geolocator.requestPermission();  // Fixed: Returns LocationPermission
      if (mounted) setState(() => _permissionStatus = permission);
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _location = position;
            if (position.accuracy > 50) {
              Fluttertoast.showToast(msg: 'Your location accuracy is low. The pin may not be precise.');
            }
          });
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasShownLocationModal', true);
        _injectLocationUpdate(position);
      } else {
        if (mounted) setState(() => _permissionStatus = LocationPermission.denied);
        if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
        Fluttertoast.showToast(msg: 'Location access is required to view the map.');
      }
    } catch (e) {
      debugPrint('Permission retry error: $e');
      Fluttertoast.showToast(msg: 'Failed to retry permission. Please try again in Dashboard.');
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<void> _returnToUserLocation() async {
    if (_permissionStatus != LocationPermission.always && _permissionStatus != LocationPermission.whileInUse) return;
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (position.accuracy > 50) {
        Fluttertoast.showToast(msg: 'Your location accuracy is low. The pin may not be precise.');
      }
      if (mounted) setState(() => _location = position);
      final script = '''
        if (window.map) {
          const userLocation = L.latLng(${position.latitude}, ${position.longitude});
          map.setView(userLocation, 16);
          if (window.clearNonActivationMarkers) window.clearNonActivationMarkers();
          const userMarker = L.marker(userLocation, { /* icon */ }).addTo(map);
          nonActivationMarkers.push(userMarker);
          fetch('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}', {
            headers: { 'User-Agent': 'BayanihanApp/1.0 (your.email@example.com)' },
          })
            .then(response => response.json())
            .then(data => userMarker.bindPopup(data.display_name || `Lat: ${position.latitude}, Lng: ${position.longitude}`).openPopup())
            .catch(error => {
              console.error("Reverse geocoding error:", error);
              userMarker.bindPopup(`Lat: ${position.latitude}, Lng: ${position.longitude}`).openPopup();
            });
        }
      ''';
      await _webViewController.runJavaScript(script);
    } catch (e) {
      debugPrint('Return to user location error: $e');
      Fluttertoast.showToast(msg: 'Failed to return to your location. Please try again.');
    }
  }

  void _toggleWeather() {
    setState(() => _showWeather = !_showWeather);
    final script = '''
      if (window.map && window.weatherMarker) {
        window.weatherMarker[${_showWeather ? 'remove' : 'addTo'}](map);
      }
    ''';
    _webViewController.runJavaScript(script);
  }

  void _toggleSearchBar() {
    setState(() => _searchBarVisible = !_searchBarVisible);
    _searchAnimController.forward();
    final script = '''
      if (window.map) {
        searchBarVisible = $_searchBarVisible;
        document.getElementById('searchContainer').classList[${_searchBarVisible ? '"remove"' : '"add"'}]('open');
        document.getElementById('searchContainer').classList[${_searchBarVisible ? '"add"' : '"remove"'}]('closed');
        document.getElementById('searchInputContainer').classList[${_searchBarVisible ? '"remove"' : '"add"'}]('hidden');
        document.getElementById('searchInputContainer').classList[${_searchBarVisible ? '"add"' : '"remove"'}]('visible');
        if ($_searchBarVisible) {
          document.getElementById('searchInput').focus();
        } else {
          document.getElementById('searchInput').value = '';
          document.getElementById('suggestions').style.display = 'none';
        }
      }
    ''';
    _webViewController.runJavaScript(script);
    if (!_searchBarVisible) {
      setState(() {
        _searchQuery = '';
        _suggestions = [];
      });
    }
  }

  void _handleSearchInput(String text) {
    setState(() => _searchQuery = text);
    final escapedText = text.replaceAll('"', '\\"');
    final script = '''
      document.getElementById('searchInput').value = "$escapedText";
      if (window.searchInputHandler) window.searchInputHandler({ target: { value: "$escapedText" } });
    ''';
    _webViewController.runJavaScript(script);
  }

  void _toggleMapType(String type) {
    setState(() => _mapType = type);
    final script = '''
      if (window.map) {
        map.eachLayer((layer) => {
          if (layer instanceof L.TileLayer) map.removeLayer(layer);
        });
        const tileLayer = "$type" === "roadmap" ? 
          L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          }) :
          L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
            attribution: '&copy; <a href="https://www.esri.com/">Esri</a>'
          });
        tileLayer.addTo(map);
      }
    ''';
    _webViewController.runJavaScript(script);
  }

  void _injectLocationUpdate(Position position) {
    final message = jsonEncode({
      'action': 'updateLocation',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'formattedAddress': 'Fetching address...',
    });
    final script = 'window.postMessage("$message");';
    _webViewController.runJavaScript(script);
  }

  void _handleWebViewMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['action'] == 'toggleSearch') {
        setState(() => _searchBarVisible = data['visible']);
      } else if (data['action'] == 'selectSuggestion') {
        setState(() {
          _searchQuery = data['formattedAddress'];
          _suggestions = [];
        });
        _loadWeather(data['latitude'], data['longitude'], false);
      } else if (data['action'] == 'requestUserLocation') {
        _returnToUserLocation();
      } else if (data['action'] == 'toggleWeather') {
        _toggleWeather();
      } else if (data['type'] == 'error') {
        Fluttertoast.showToast(msg: data['message']);
      }
    } catch (e) {
      debugPrint('WebView message error: $e');
    }
  }

  Future<void> _loadWeather(double lat, double lng, bool isUserLocation) async {
    try {
      final cacheKey = '${lat}_$lng';
      if (_weatherCache.containsKey(cacheKey)) {
        _createWeatherPopup(lat, lng, _weatherCache[cacheKey]!, isUserLocation);
        return;
      }
      final response = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&appid=$_openWeatherApiKey&units=metric',
      ));
      if (response.statusCode == 200) {
        final weatherData = jsonDecode(response.body);
        _weatherCache[cacheKey] = weatherData;
        _createWeatherPopup(lat, lng, weatherData, isUserLocation);
      } else {
        throw Exception('Weather API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
      Fluttertoast.showToast(msg: 'Failed to load weather data: $e');
    }
  }

  void _createWeatherPopup(double lat, double lng, Map<String, dynamic> weatherData, bool isUserLocation) {
    // Fixed: Basic JS injection for weather popup (expand as needed)
    final condition = (weatherData['weather'][0]['main'] as String).toLowerCase();
    final temp = weatherData['main']['temp'];
    final description = weatherData['weather'][0]['description'];
    final icon = condition.contains('clear') ? '☀️' : condition.contains('rain') || condition.contains('drizzle') || condition.contains('thunderstorm') ? '🌧️' : condition.contains('clouds') ? '☁️' : '🌫️';
    final popupContent = '''
      <div class="bayanihan-infowindow">
        <h3 style="color: black; font-family: 'Poppins', sans-serif;">
          <span style="font-size: 24px;">$icon</span>
          Weather at ${isUserLocation ? 'Your Location' : 'Selected Location'}
        </h3>
        <p><strong style="color: black; font-weight: bold;">Condition:</strong> $description</p>
        <p><strong style="color: black; font-weight: bold;">Temperature:</strong> $temp°C</p>
        <p><strong style="color: black; font-weight: bold;">Humidity:</strong> ${weatherData['main']['humidity']}%</p>
        <p><strong style="color: black; font-weight: bold;">Wind Speed:</strong> ${weatherData['wind']['speed']} m/s</p>
      </div>
    ''';
    final script = '''
      if (window.weatherMarker) window.weatherMarker.remove();
      const weatherMarker = L.marker([$lat, $lng], {
        title: "Weather",
        icon: L.divIcon({
          html: '<span style="font-size: 24px;">$icon</span>',
          className: 'custom-marker',
          iconSize: [30, 30],
          iconAnchor: [15, 30],
          popupAnchor: [0, -30],
        }),
      });
      weatherMarker.on('click', () => {
        if (window.singlePopup && window.singlePopup._source !== weatherMarker) window.singlePopup.remove();
        window.singlePopup = L.popup().setContent(`$popupContent`).setLatLng([$lat, $lng]).openOn(map);
      });
      if ($_showWeather) weatherMarker.addTo(map);
    ''';
    _webViewController.runJavaScript(script);
  }

  void _showErrorModal(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.error, color: Colors.red, size: 48),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<myAuth.AuthProvider>(context);
    final userName = _getUserName(authProvider) ?? 'Unknown User';  // Fixed: Null-safe String

    if (_permissionStatus == LocationPermission.denied || _location == null) {
      return Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x6614AEBA), ThemeConstants.lightBg],
                  begin: Alignment.topRight,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Ionicons.menu, size: 32, color: ThemeConstants.primary),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Text(
                          userName,  // Fixed: Now guaranteed String
                          style: TextStyle(color: ThemeConstants.primary, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Permission Denied UI
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 48, color: Colors.red),
                      const Text('Location Access Denied', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Text('Please enable location access in Dashboard to view the map and experience our services.'),
                      ),
                      ElevatedButton(
                        onPressed: _handleRetryPermission,
                        child: const Text('Allow Location Access'),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // WebView Map
          if (_mapHtml.isNotEmpty)
            Builder(  // Fixed: Use Builder to load HTML post-build
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _webViewController.loadHtmlString(_mapHtml);  // Fixed: Call on controller
                  _webViewController.setNavigationDelegate(
                    NavigationDelegate(
                      onPageFinished: (url) {
                        if (mounted) setState(() => _webViewLoaded = true);
                        _isLoading = false;
                      },
                      onWebResourceError: (error) {
                        Fluttertoast.showToast(msg: 'Failed to load the map. Please check your internet connection.');
                      },
                    ),
                  );
                });
                return WebViewWidget(controller: WebViewController());
              },
            ),
          // Loading Overlay
          if (_isLoading)
            Container(
              color: ThemeConstants.lightBg,
              child: const Center(child: CircularProgressIndicator()),
            ),
          // Header Overlay (blurred)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top + 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ThemeConstants.white.withOpacity(0.8),
                    ThemeConstants.white.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Ionicons.menu, size: 32, color: ThemeConstants.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Text(userName, style: const TextStyle(color: ThemeConstants.white, fontSize: 18)),  // Fixed: String
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Map Type Buttons (absolute)
          Positioned(
            top: 180,
            left: 10,
            child: Column(
              children: [
                _MapTypeButton(
                  icon: Icons.map,
                  label: 'Map',
                  isActive: _mapType == 'roadmap',
                  onPressed: () => _toggleMapType('roadmap'),
                ),
                const SizedBox(height: 8),
                _MapTypeButton(
                  icon: Icons.satellite_alt,  // Better icon for hybrid/satellite
                  label: 'Satellite',
                  isActive: _mapType == 'hybrid',  // Fixed: Align to 'hybrid'
                  onPressed: () => _toggleMapType('hybrid'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Widget for Map Type Buttons
class _MapTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _MapTypeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThemeConstants.primary.withOpacity(isActive ? 1 : 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? ThemeConstants.white : ThemeConstants.primary),
            Text(label, style: TextStyle(color: isActive ? ThemeConstants.white : ThemeConstants.primary)),
          ],
        ),
      ),
    );
  }
}