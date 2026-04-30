/// Network configuration — change [kBackendHost] when the backend machine IP changes.
///
/// Usage:
///   • Same machine  : localhost (web dev)
///   • LAN / physical devices : your PC's local IP (e.g. 192.168.1.16)
///   • Production    : your public domain / VPS IP

/// The IP address (or hostname) of the machine running the backend server.
/// Update this whenever the backend machine's LAN IP changes.
const String kBackendHost = '10.121.216.80';

/// The port the backend Express server listens on.
const int kBackendPort = 3000;
