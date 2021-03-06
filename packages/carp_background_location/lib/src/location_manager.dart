part of carp_background_location;

class LocationManager {
  ReceivePort _port = ReceivePort();
  Stream<LocationDto> _dtoStream;
  String _channelName = "BackgroundLocationChannel",
      _notificationTitle = "Background Location",
      _notificationMsg = "Your location is being tracked";

  int _interval = 1;
  double _distanceFilter = 0;

  /// Getting the stream that provides location data updates
  Stream<LocationDto> get dtoStream {
    if (_dtoStream == null) {
      Stream<dynamic> dataStream = _port.asBroadcastStream();
      _dtoStream = dataStream.where((event) => event != null).map((e) {
        LocationDto dto = e as LocationDto;
        return dto;
      });
    }
    return _dtoStream;
  }

  /// Get the status of the location manager.
  /// Will return true if a location service is currently running.
  Future<bool> get isRunning async =>
      await BackgroundLocator.isRegisterLocationUpdate();

  /// Private static instance of the [LocationManager] singleton
  static final LocationManager _instance = LocationManager._();

  /// Get the singleton [LocationManager] instance
  static LocationManager get instance => _instance;

  /// Singleton constructor, i.e. private
  LocationManager._() {
    /// Check if the port is already used
    if (IsolateNameServer.lookupPortByName(
            LocationServiceRepository.isolateName) !=
        null) {
      IsolateNameServer.removePortNameMapping(
          LocationServiceRepository.isolateName);
    }

    /// Register the service to the port name
    IsolateNameServer.registerPortWithName(
        _port.sendPort, LocationServiceRepository.isolateName);
  }

  /// Get a single location update by listening
  /// to the stream until an update is given,
  /// upon which the data point is returned to the caller.
  Future<LocationDto> getCurrentLocation() async {
    LocationDto dto;
    if (!await BackgroundLocator.isRegisterLocationUpdate()) {
      await start();
      dto = await dtoStream.first;
      stop();
      return dto;
    }
    return await dtoStream.first;
  }

  /// Start the location service.
  /// Will have no effect if it is already running.
  Future<void> start({bool askForPermission: true}) async {
    print('Initializing...');
    await BackgroundLocator.initialize();
    print('Initialization done');

    if (askForPermission) {
      if (await _checkLocationPermission()) {
        _startLocator();
      }
    } else {
      _startLocator();
    }
  }

  /// Stop the location service.
  /// Has no effect if the service is not currently running.
  Future<void> stop() async {
    await BackgroundLocator.unRegisterLocationUpdate();
  }

  /// Check whether or not location permissions have been granted.
  /// Location permissions are necessary for getting location updates.
  Future<bool> checkIfPermissionGranted() async {
    final access = await LocationPermissions().checkPermissionStatus();
    return access == PermissionStatus.granted;
  }

  /// Checks the status of the location permission.
  /// The status can be either of these
  ///     - Unknown (i.e. has not been requested)
  ///     - Denied (i.e. no access)
  ///     - Restricted (i.e. only once/when app is in foreground)
  ///     - Always (i.e. works in the foreground and the background)
  Future<bool> _checkLocationPermission() async {
    final access = await LocationPermissions().checkPermissionStatus();
    switch (access) {
      case PermissionStatus.unknown:
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
        final permission = await LocationPermissions().requestPermissions(
          permissionLevel: LocationPermissionLevel.locationAlways,
        );
        if (permission == PermissionStatus.granted) {
          return true;
        } else {
          return false;
        }
        break;
      case PermissionStatus.granted:
        return true;
        break;
      default:
        return false;
        break;
    }
  }

  /// Starts the location service with the given parameters.
  void _startLocator() {
    BackgroundLocator.registerLocationUpdate(
      LocationCallbackHandler.callback,
      initCallback: LocationCallbackHandler.initCallback,
      disposeCallback: LocationCallbackHandler.disposeCallback,
      androidNotificationCallback: LocationCallbackHandler.notificationCallback,
      settings: LocationSettings(
          notificationChannelName: _channelName,
          notificationTitle: _notificationTitle,
          notificationMsg: _notificationMsg,
          autoStop: false,
          distanceFilter: _distanceFilter,
          interval: _interval),
    );
  }

  /// Set the title of the notification for the background service.
  /// Android only.
  set notificationTitle(value) {
    _notificationTitle = value;
  }

  /// Set the title of the notification for the background service.
  /// Android only.
  set notificationMsg(value) {
    _notificationMsg = value;
  }

  /// Set the update distance, i.e. the distance the user needs to move
  /// before an update is fired.
  set distanceFilter(double value) {
    _distanceFilter = value;
  }

  /// Set the update interval in seconds.
  set interval(int value) {
    _interval = value;
  }
}
