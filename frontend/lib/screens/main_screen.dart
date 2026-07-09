import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:sartaroshxona/models/barber.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/screens/home_screen.dart';
import 'package:sartaroshxona/screens/customer_appointments_screen.dart';
import 'package:sartaroshxona/screens/barber_details_screen.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/user_profile_screen.dart';
import 'package:sartaroshxona/widgets/animated_nav_bar.dart';
import 'package:sartaroshxona/utils/auth_guard.dart';
import 'package:sartaroshxona/widgets/glass.dart';


class MainScreen extends StatefulWidget {
  final String userName;
  final int userId;

  const MainScreen({super.key, required this.userName, required this.userId});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  late final List<Widget> _pages;

  bool get _isGuest => AuthGuard.isGuest(widget.userId);

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(userName: widget.userName, userId: widget.userId),
      _BarbersMapTab(userId: widget.userId),
      // Mehmon uchun navbatlar/profil — login so'rovi ko'rsatiladi
      _isGuest
          ? const GuestPrompt(
              icon: Icons.calendar_month_rounded,
              title: "Navbatlaringiz shu yerda",
              message: "Navbatlaringizni ko'rish va boshqarish uchun ro'yxatdan o'ting yoki kiring.",
            )
          : CustomerAppointmentsScreen(userId: widget.userId),
      _isGuest
          ? const GuestPrompt(
              icon: Icons.account_circle_outlined,
              title: "Profilingiz",
              message: "Profil, sevimlilar va to'lov tarixini ko'rish uchun hisobingizga kiring.",
            )
          : UserProfileScreen(userName: widget.userName, userId: widget.userId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        // Chap/o'ngga surganda sahifa almashadi
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: _pages
            .map((page) => _KeepAlivePage(child: page))
            .toList(),
      ),
      bottomNavigationBar: AnimatedNavBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }

  /// Pastdagi nav-bar bosilganda — animatsiya bilan o'sha sahifaga o'tish
  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

/// PageView sahifalarini "tirik" saqlaydi (IndexedStack kabi holatni yo'qotmaydi).
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─── MAP TAB ──────────────────────────────────────────────────────────────────

class _BarbersMapTab extends StatefulWidget {
  final int userId;
  const _BarbersMapTab({required this.userId});

  @override
  _BarbersMapTabState createState() => _BarbersMapTabState();
}

class _BarbersMapTabState extends State<_BarbersMapTab> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<Barber> _barbers = [];
  bool _isLoading = true;
  String _statusText = "Yuklanmoqda...";

  static const LatLng _tashkentCenter = LatLng(41.3111, 69.2797);

  // Foydalanuvchining haqiqiy joylashuvi (GPS). Standart — Toshkent.
  LatLng _userCenter = _tashkentCenter;
  bool _locationResolved = false;

  // Qidiruv radiusi (km) — foydalanuvchi tanlaydi (2..50)
  double _radiusKm = 5.0;
  static const List<double> _radiusOptions = [2, 5, 10, 25, 50];

  // Radiusga mos zoom darajasi
  double _zoomForRadius(double km) {
    if (km <= 2) return 14;
    if (km <= 5) return 13;
    if (km <= 10) return 12;
    if (km <= 25) return 11;
    return 10;
  }

  @override
  void initState() {
    super.initState();
    _initLocationAndBarbers();
  }

  /// GPS orqali foydalanuvchi joylashuvini aniqlaydi, keyin shu nuqtadan
  /// sartaroshlarni yuklaydi va kamerani foydalanuvchiga markazlaydi.
  Future<void> _initLocationAndBarbers() async {
    try {
      final location = Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await location.requestService();

      PermissionStatus permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }

      if (serviceEnabled && permission == PermissionStatus.granted) {
        final data = await location.getLocation();
        if (data.latitude != null && data.longitude != null) {
          _userCenter = LatLng(data.latitude!, data.longitude!);
          _locationResolved = true;
        }
      }
    } catch (e) {
      debugPrint("Map GPS xatolik: $e");
    }

    // Kamerani foydalanuvchi joylashuviga olib boramiz
    if (_mapController != null && _locationResolved) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_userCenter, 13));
    }

    await _loadBarbers();
  }

  Future<BitmapDescriptor> _createBarberMarker(bool isOnline) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(80, 100);

    final bgPaint = Paint()
      ..color = isOnline ? const Color(0xFF2ECC71) : const Color(0xFF8899AA)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(size.width / 2 + 2, size.height / 2 - 8), 32, shadowPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 - 10), 32, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 - 10), 32, borderPaint);

    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2 - 10;

    canvas.drawLine(Offset(cx - 8, cy - 8), Offset(cx + 8, cy + 8), iconPaint);
    canvas.drawLine(Offset(cx + 8, cy - 8), Offset(cx - 8, cy + 8), iconPaint);

    final dotPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 3, dotPaint);

    final path = Path()
      ..moveTo(size.width / 2 - 10, size.height / 2 + 20)
      ..lineTo(size.width / 2 + 10, size.height / 2 + 20)
      ..lineTo(size.width / 2, size.height / 2 + 38)
      ..close();
    canvas.drawPath(path, bgPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _loadBarbers() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _statusText = "Sartaroshlar qidirilmoqda..."; });

    try {
      // Radius bo'yicha — foydalanuvchi atrofidagi sartaroshlar
      final barbers = await ApiService().fetchBarbers(
        _userCenter.latitude, _userCenter.longitude,
        radiusKm: _radiusKm,
      );
      if (!mounted) return;

      if (barbers.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusText = "${_radiusKm.toInt()} km radiusda sartarosh topilmadi";
          _barbers = [];
          _markers = {};
        });
        // Sartarosh bo'lmasa ham foydalanuvchiga markazlaymiz
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_userCenter, _zoomForRadius(_radiusKm)));
        return;
      }

      final Set<Marker> markers = {};
      for (final barber in barbers) {
        BitmapDescriptor icon;
        try {
          icon = await _createBarberMarker(barber.isOnline);
        } catch (_) {
          icon = BitmapDescriptor.defaultMarkerWithHue(barber.isOnline ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed);
        }

        markers.add(Marker(
          markerId: MarkerId(barber.id.toString()),
          position: LatLng(barber.lat, barber.lng),
          icon: icon,
          infoWindow: InfoWindow(
            title: barber.name,
            snippet: "${barber.district} • ${barber.rating} • ${barber.isOnline ? 'Online' : 'Offline'}",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BarberDetailsScreen(barber: barber, userId: widget.userId))),
          ),
        ));
      }

      if (!mounted) return;
      setState(() {
        _barbers = barbers;
        _markers = markers;
        _isLoading = false;
        _statusText = "${_radiusKm.toInt()} km da ${barbers.length} ta sartarosh";
      });

      // Fit-to-markers EMAS — foydalanuvchi joylashuviga markazlaymiz (Toshkentga ketmaslik uchun)
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_userCenter, _zoomForRadius(_radiusKm)));
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _statusText = "Xatolik yuz berdi"; });
    }
  }

  /// Refresh tugmasi — joylashuvni QAYTA aniqlaydi va atrofdagi sartaroshlarni yangilaydi
  Future<void> _refreshFromCurrentLocation() async {
    setState(() { _isLoading = true; _statusText = "Joylashuv aniqlanmoqda..."; });
    try {
      final location = Location();
      final data = await location.getLocation();
      if (data.latitude != null && data.longitude != null) {
        _userCenter = LatLng(data.latitude!, data.longitude!);
        _locationResolved = true;
      }
    } catch (e) {
      debugPrint("Refresh GPS xatolik: $e");
    }
    await _loadBarbers();
  }

  void _fitMarkersOnMap() {
    if (_barbers.isEmpty || _mapController == null) return;
    double minLat = _barbers.first.lat, maxLat = _barbers.first.lat;
    double minLng = _barbers.first.lng, maxLng = _barbers.first.lng;
    for (final b in _barbers) {
      if (b.lat < minLat) minLat = b.lat;
      if (b.lat > maxLat) maxLat = b.lat;
      if (b.lng < minLng) minLng = b.lng;
      if (b.lng > maxLng) maxLng = b.lng;
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat - 0.01, minLng - 0.01), northeast: LatLng(maxLat + 0.01, maxLng + 0.01)), 80,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onlineCount = _barbers.where((b) => b.isOnline).length;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _userCenter, zoom: 13),
          markers: _markers,
          onMapCreated: (c) {
            _mapController = c;
            // Joylashuv allaqachon aniqlangan bo'lsa — o'shanga boramiz
            if (_locationResolved) {
              c.animateCamera(CameraUpdate.newLatLngZoom(_userCenter, 13));
            } else if (_markers.isNotEmpty) {
              _fitMarkersOnMap();
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          mapType: MapType.normal,
          zoomControlsEnabled: false,
          compassEnabled: true,
        ),

        // Top info bar
        Positioned(
          top: 50, left: 15, right: 15,
          child: GlassContainer(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.content_cut_rounded, color: colors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_isLoading ? "Sartaroshlar qidirilmoqda..." : _statusText, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold))),
                if (!_isLoading && onlineCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: colors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.success.withOpacity(0.3))),
                    child: Row(children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: colors.success)),
                      const SizedBox(width: 4),
                      Text('$onlineCount online', style: TextStyle(color: colors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ],
            ),
          ),
        ),

        if (_isLoading)
          Center(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)), child: CircularProgressIndicator(color: colors.primary))),

        // Radius selector (2..50 km)
        Positioned(
          top: 108, left: 15, right: 15,
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _radiusOptions.map((km) {
                final selected = _radiusKm == km;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      if (_radiusKm != km) {
                        setState(() => _radiusKm = km);
                        _loadBarbers();
                      }
                    },
                    child: GlassContainer(
                      borderRadius: 20,
                      glow: selected,
                      opacity: selected ? 0.85 : 0.55,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location_rounded, size: 13, color: selected ? colors.primary : colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            "${km.toInt()} km",
                            style: TextStyle(
                              color: selected ? colors.primary : colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Bottom barbers list (ixcham — yarmiga kichraytirilgan)
        if (!_isLoading && _barbers.isNotEmpty)
          Positioned(
            bottom: 80, left: 0, right: 0,
            child: SizedBox(
              height: 58,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _barbers.length,
                itemBuilder: (_, i) {
                  final b = _barbers[i];
                  return GestureDetector(
                    onTap: () {
                      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(b.lat, b.lng), 16));
                      Future.delayed(const Duration(milliseconds: 500), () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => BarberDetailsScreen(barber: b, userId: widget.userId)));
                      });
                    },
                    child: Container(
                      width: 132,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: colors.surface.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: b.isOnline ? colors.success.withOpacity(0.4) : colors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: b.isOnline ? [colors.primary, colors.primaryLight] : [colors.textSecondary, colors.textSecondary])),
                            child: Center(child: Text(b.name.isNotEmpty ? b.name[0].toUpperCase() : 'S', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(b.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 1),
                                Row(children: [
                                  const Icon(Icons.star_rounded, size: 9, color: Colors.amber),
                                  Text(' ${b.rating}', style: TextStyle(color: colors.textSecondary, fontSize: 9)),
                                  const SizedBox(width: 4),
                                  Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: b.isOnline ? colors.success : colors.textSecondary)),
                                  const SizedBox(width: 2),
                                  Text(b.isOnline ? 'Online' : 'Offline', style: TextStyle(color: b.isOnline ? colors.success : colors.textSecondary, fontSize: 8, fontWeight: FontWeight.bold)),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // FAB buttons
        Positioned(
          bottom: 24, right: 16,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'location',
                backgroundColor: colors.surface,
                onPressed: () => _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_userCenter, 14)),
                child: Icon(Icons.my_location_rounded, color: colors.primary),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'refresh',
                backgroundColor: colors.primary,
                onPressed: _refreshFromCurrentLocation,
                child: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
