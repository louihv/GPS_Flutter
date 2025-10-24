import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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
  LocationPermission? _permissionStatus;
  bool _searchBarVisible = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _suggestions = [];
  String _mapType = 'roadmap';
  bool _showWeather = false;
  late AnimationController _searchAnimController;
  late Animation<double> _searchAnim;
  late final WebViewController _webViewController;
  final Map<String, Map<String, dynamic>> _weatherCache = {};
  bool _isLoading = true;
  bool _webViewLoaded = false; 
  String? _contactPerson;
  String? _firstName;
  String? _lastName;
  int _selectedIndex = 0;


  // Replace with OpenWeatherMap API key
  // static const String _openWeatherApiKey = 'YOUR_OPEN_WEATHER_API_KEY_HERE';

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
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(ThemeConstants.lightBg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _webViewLoaded = true;
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'ReactNativeWebView',
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
    top: 80px; 
    left: 10px; 
    z-index: 999; 
    display: flex;           
    flex-direction: column;    
    gap: 8px;  
  }
  .map-type-button {
    background: #14aebb;
    color: white;
    padding: 8px 12px;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    font-family: 'Poppins', sans-serif;
    font-size: 14px;
  }
  .map-type-button.active {
    background: #0d8a94;
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
  .get-directions-btn {
    background: #14aebb;
    color: white;
    padding: 8px 12px;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-family: 'Poppins', sans-serif;
    font-size: 14px;
    margin-top: 10px;
    display: block;
    width: 100%;
    text-align: center;
  }
  .get-directions-btn:hover {
    background: #0d8a94;
  }
  @keyframes slideIn {
    0% { transform: translateY(10px); opacity: 0; }
    100% { transform: translateY(0); opacity: 1; }
  }
  .custom-marker {
    font-size: 24px;
    text-align: center;
  }
  #searchIcon{
  color: 'black'
  }
''';


String get _mapHtml {
  if (_permissionStatus != LocationPermission.always && _permissionStatus != LocationPermission.whileInUse || _location == null) {
    return '';
  }
  return '''
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <link href='https://cdn.boxicons.com/2.1.4/css/boxicons.min.css' rel='stylesheet'>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600&display=swap" rel="stylesheet">
    <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
    <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>
    <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-database-compat.js"></script>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>$_mapStyles</style>
  </head>
  <body>
    <div class="overlay-container">
      <div class="search-wrapper">
        <div id="searchContainer" class="search-container closed">
          <span id="searchIcon" class="search-icon"><i class='bx bx-search'></i></span>
          <div id="searchInputContainer" class="search-input-container hidden">
            <input id="searchInput" class="search-input" type="text" placeholder="Search for a location" />
          </div>
        </div>
        <div id="suggestions" class="suggestions-container"></div>
        <button id="returnButton" class="return-button">
          <ion-icon name="locate-outline" style="font-size: 28px; color: white;"></ion-icon>
        </button>
      </div>
      <div class="map-type-buttons-container">
        <button id="roadmapBtn" class="map-type-button active">
          <ion-icon name="map-outline"></ion-icon> 
        </button>
        <button id="hybridBtn" class="map-type-button">
          <ion-icon name="earth-outline"></ion-icon> 
        </button>
      </div>
    </div>
    <div id="map"></div>
    <script>
      const firebaseConfig = {
        apiKey: "AIzaSyBg7HFyVCx2Hlox21C9a9WuoC6IU6cKMWw",
        authDomain: "bayanihan-flutter.firebaseapp.com",
        databaseURL: "https://bayanihan-flutter-default-rtdb.firebaseio.com",
        projectId: "bayanihan-flutter",
        storageBucket: "bayanihan-flutter.firebasestorage.app",
        messagingSenderId: "433015377389",
        appId: "1:433015377389:web:f602d574a2d4e196cb2be4",
        measurementId: "G-23XZW2NB66"
      };
      firebase.initializeApp(firebaseConfig);
      const database = firebase.database();
      let map, userMarker, weatherMarker, currentLayer, currentPolyline;
      let activationMarkers = [];
      let nonActivationMarkers = [];
      let singlePopup;
      let weatherCache = new Map();
      let searchBarVisible = false;
      let mapType = '$_mapType';

      // Polyline decoder function for OSRM encoded geometry
      function decodePolyline(encoded) {
        let points = [];
        let index = 0, len = encoded.length;
        let lat = 0, lng = 0;
        while (index < len) {
          let b, shift = 0, result = 0;
          do {
            b = encoded.charCodeAt(index++) - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
          } while (b >= 0x20);
          let dlat = ((result & 1) ? ~(result >> 1) : (result >> 1));
          lat += dlat;
          shift = 0;
          result = 0;
          do {
            b = encoded.charCodeAt(index++) - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
          } while (b >= 0x20);
          let dlng = ((result & 1) ? ~(result >> 1) : (result >> 1));
          lng += dlng;
          points.push([lat / 1e5, lng / 1e5]);
        }
        return points;
      }

      function initMap() {
        try {
          const userLocation = L.latLng(${_location!.latitude}, ${_location!.longitude});
          map = L.map('map', {
            center: userLocation,
            zoom: 16,
            zoomControl: false,
            attributionControl: true,
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
          document.getElementById('searchInput').addEventListener('input', async function (e) {
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
          });
          document.getElementById('returnButton').addEventListener('click', function () {
            window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'requestUserLocation' }));
          });
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
        } catch (error) {
          console.error("Map initialization error:", error);
          window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'showError', message: 'Map initialization failed: ' + error.message }));
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
              window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'showInfo', message: 'No active activations found.' }));
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
                  html: `<span><ion-icon name="people-circle-outline" style="color: #FA3B99; font-size: 50px;"></ion-icon></span>`,
                  className: 'custom-marker',
                  iconSize: [30, 30],
                  iconAnchor: [15, 30],
                  popupAnchor: [0, -30],
                }),
              }).addTo(map);
              activationMarkers.push(marker);
              createPopup(marker, activation, logoPath, lat, lng);
            });
          });
        } catch (error) {
          console.error("Error in loadActivations:", error.message);
          window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'showError', message: 'Activation loading failed: ' + error.message }));
        }
      }

      function createPopup(marker, activation, logoPath, lat, lng) {
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
                <button class="get-directions-btn" onclick="window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'getDirections', latitude: \${lat}, longitude: \${lng}, organization: '\${activation.organization || 'Unknown Organization'}' }))">Get Directions</button>
              </div>
            `;
            marker.on('click', () => {
              if (singlePopup && singlePopup._source !== marker) singlePopup.remove();
              singlePopup = L.popup().setContent(content).setLatLng(marker.getLatLng()).openOn(map);
            });
          });
      }

      async function drawPolyline(startLat, startLng, endLat, endLng) {
        try {
          if (currentPolyline) {
            currentPolyline.remove();
            currentPolyline = null;
          }
          // Fetch route from OSRM
          const response = await fetch(
            `http://router.project-osrm.org/route/v1/driving/\${startLng},\${startLat};\${endLng},\${endLat}?overview=full&geometries=polyline`
          );
          if (!response.ok) throw new Error(`OSRM API error: \${response.status}`);
          const data = await response.json();
          if (data.code !== 'Ok' || !data.routes || data.routes.length === 0) {
            throw new Error('No route found');
          }
          const geometry = data.routes[0].geometry;
          const points = decodePolyline(geometry);
          currentPolyline = L.polyline(points, {
            color: '#14aebb',
            weight: 4,
            opacity: 0.8
          }).addTo(map);
          // Adjust map view to fit the polyline
          const bounds = L.latLngBounds(points);
          map.fitBounds(bounds, { padding: [50, 50] });
        } catch (error) {
          console.error('Routing error:', error);
          window.ReactNativeWebView.postMessage(JSON.stringify({
            action: 'showError',
            message: 'Failed to calculate route. Using straight line as fallback.'
          }));
          // Fallback to straight line
          currentPolyline = L.polyline([
            [startLat, startLng],
            [endLat, endLng]
          ], {
            color: '#14aebb',
            weight: 4,
            opacity: 0.8
          }).addTo(map);
          const bounds = L.latLngBounds([[startLat, startLng], [endLat, endLng]]);
          map.fitBounds(bounds, { padding: [50, 50] });
        }
      }

      function clearPolyline() {
        if (currentPolyline) {
          currentPolyline.remove();
          currentPolyline = null;
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
          window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'showError', message: 'Failed to load weather data: ' + error.message }));
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
            const userMarker = L.marker(userLocation, {
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
            userMarker.bindPopup(data.formattedAddress || `Lat: \${data.latitude}, Lng: \${data.longitude}`).openPopup();
          } else if (data.action === 'requestUserLocation') {
            window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'requestUserLocation' }));
          } else if (data.action === 'toggleWeather') {
            if (weatherMarker) weatherMarker[${_showWeather ? 'remove' : 'addTo'}](map);
          } else if (data.action === 'selectSuggestion') {
            setTimeout(() => loadWeather(data.latitude, data.longitude, false), 0);
          } else if (data.action === 'showError') {
            window.ReactNativeWebView.postMessage(JSON.stringify({ action: 'showError', message: data.message }));
          } else if (data.action === 'drawPolyline') {
            drawPolyline(data.startLat, data.startLng, data.endLat, data.endLng);
          } else if (data.action === 'clearPolyline') {
            clearPolyline();
          }
        } catch (error) {
          console.error('Message parsing error:', error);
        }
      });

      window.initMap = initMap;
      window.clearNonActivationMarkers = clearNonActivationMarkers;
      window.drawPolyline = drawPolyline;
      window.clearPolyline = clearPolyline;
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
      setState(() => _isLoading = true); // Ensure loading state during permission check
      final prefs = await SharedPreferences.getInstance();
      final hasShownPrompt = prefs.getBool('hasShownLocationPrompt') ?? false;
      final permission = await Geolocator.checkPermission();
      if (mounted) {
        setState(() => _permissionStatus = permission);
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _location = position;
            if (position.accuracy > 50) {
              Fluttertoast.showToast(msg: 'Your location accuracy is low. The pin may not be precise.');
            }
            _isLoading = true; // Keep loading until WebView is ready
            _webViewController.loadHtmlString(_mapHtml); // Load map immediately
          });
        }
        if (!hasShownPrompt) {
          await prefs.setBool('hasShownLocationPrompt', true);
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _permissionStatus = permission;
          });
        }
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
      if (mounted) {
        setState(() {
          _permissionStatus = LocationPermission.denied;
          _isLoading = false;
        });
      }
      Fluttertoast.showToast(msg: 'Failed to check location permission. Please try again.');
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
      final db = FirebaseDatabase.instance.ref();
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
    }
  }

  Future<void> _handleRetryPermission() async {
    try {
      setState(() => _isLoading = true); // Show loading during permission retry
      final permission = await Geolocator.requestPermission();
      if (mounted) setState(() => _permissionStatus = permission);
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _location = position;
            if (position.accuracy > 50) {
              Fluttertoast.showToast(msg: 'Your location accuracy is low. The pin may not be precise.');
            }
            _isLoading = true; // Keep loading until WebView is ready
            _webViewController.loadHtmlString(_mapHtml); // Load map immediately
          });
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasShownLocationPrompt', true);
        _injectLocationUpdate(position);
      } else {
        if (mounted) {
          setState(() {
            _permissionStatus = permission;
            _isLoading = false;
          });
        }
        Fluttertoast.showToast(msg: 'Location access is required to view the map.');
      }
    } catch (e) {
      debugPrint('Permission retry error: $e');
      if (mounted) setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: 'Failed to retry permission. Please try again.');
    }
  }

  Future<void> _returnToUserLocation() async {
    if (_permissionStatus != LocationPermission.always && _permissionStatus != LocationPermission.whileInUse) {
      Fluttertoast.showToast(msg: 'Location access is required to return to your location.');
      return;
    }
    try {
      setState(() => _isLoading = true); // Show loading during location update
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
          const userMarker = L.marker(userLocation, {
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
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Return to user location error: $e');
      if (mounted) setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: 'Failed to return to your location. Please try again.');
    }
  }

  void _toggleWeather() {
    setState(() => _showWeather = !_showWeather);
    final script = '''
      if (window.map && window.weatherMarker) {
        window.weatherMarker[${_showWeather ? 'addTo' : 'remove'}](map);
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
        document.getElementById('searchContainer').classList[${_searchBarVisible ? '"remove"' : '"add"'}]('closed');
        document.getElementById('searchContainer').classList[${_searchBarVisible ? '"add"' : '"remove"'}]('open');
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
        map.removeLayer(window.currentLayer);
        window.currentLayer = "$type" === "roadmap" ? 
          L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            maxZoom: 18,
          }) :
          L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
            attribution: '&copy; <a href="https://www.esri.com/">Esri</a>',
            maxZoom: 18,
          });
        window.currentLayer.addTo(map);
        window.mapType = "$type";
        document.getElementById('roadmapBtn').classList[${type == 'roadmap' ? '"add"' : '"remove"'}]('active');
        document.getElementById('hybridBtn').classList[${type == 'hybrid' ? '"add"' : '"remove"'}]('active');
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
    } else if (data['action'] == 'requestUserLocation') {
      _returnToUserLocation();
    } else if (data['action'] == 'toggleWeather') {
      _toggleWeather();
    } else if (data['action'] == 'showError' || data['action'] == 'showInfo') {
      Fluttertoast.showToast(msg: data['message']);
    } else if (data['action'] == 'getDirections') {
      // Show modal with group info and "Get Directions" button
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(data['organization'] ?? 'Unknown Organization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location: (${data['latitude']}, ${data['longitude']})'),
              const SizedBox(height: 10),
              Text('Would you like to see directions to this group?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_location != null) {
                  // Clear existing polyline
                  _webViewController.runJavaScript('window.clearPolyline();');
                  // Draw new polyline
                  final script = '''
                    window.drawPolyline(${_location!.latitude}, ${_location!.longitude}, ${data['latitude']}, ${data['longitude']});
                  ''';
                  _webViewController.runJavaScript(script);
                  Navigator.of(context).pop();
                } else {
                  Fluttertoast.showToast(msg: 'User location not available.');
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConstants.primary,
                foregroundColor: ThemeConstants.white,
              ),
              child: const Text('Get Directions'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    debugPrint('WebView message error: $e');
  }
}


  void _createWeatherPopup(double lat, double lng, Map<String, dynamic> weatherData, bool isUserLocation) {
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

    void _onNavBarTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<myAuth.AuthProvider>(context);
    final userName = _getUserName(authProvider) ?? 'Unknown User';

    if (_permissionStatus == LocationPermission.denied || _permissionStatus == LocationPermission.deniedForever || _location == null) {
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
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: Text(
                        userName,
                        style: const TextStyle(color: ThemeConstants.primary, fontSize: 18),
                      ),
                    ),
                  ),
                  const Spacer(),                 
                  const Spacer(),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: ThemeConstants.lightBg,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            Container(
              color: ThemeConstants.lightBg,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      
    );
  }
}

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
            Text(
              label,
              style: TextStyle(color: isActive ? ThemeConstants.white : ThemeConstants.primary),
            ),
          ],
        ),
      ),
    );
  }
}