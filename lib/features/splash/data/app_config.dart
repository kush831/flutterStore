import '../../../core/network/json_reader.dart';
import '../../../core/strings/app_language.dart';

class ConfigLanguage {
  const ConfigLanguage({required this.name, required this.locale});

  final String name; // shown in its own language ("Français")
  final String locale; // the `locale` header value ("fr")

  factory ConfigLanguage.fromJson(JsonReader r) => ConfigLanguage(name: r.text('name'), locale: r.text('locale'));
}

class CmsPage {
  const CmsPage({required this.slug, required this.title,this.description = ''});

  final String slug;
  final String title;
  final String description;

  factory CmsPage.fromJson(JsonReader r) =>
      CmsPage(slug: r.text('slug'), title: r.str('tile') ?? r.str('title') ?? r.text('slug'),
        description: r.text('description'),); // the API spells it "tile"

}

class UpdateInfo {
  const UpdateInfo({this.show = false, this.mandatory = false, this.message = '', this.iosStoreAppId = '', this.iosStoreLink = ''});

  final bool show;
  final bool mandatory;
  final String message;
  final String iosStoreAppId;
  final String iosStoreLink;

  factory UpdateInfo.fromJson(JsonReader r) => UpdateInfo(
    show: r.flag('showDialog'),
    mandatory: r.flag('mandatory'),
    message: r.text('dialogMessage'),
    iosStoreAppId: r.text('iosStoreAppid'),
    iosStoreLink: r.text('iosStoreLink'),
  );
}

class MaintenanceInfo {
  const MaintenanceInfo({this.show = false, this.message = ''});

  final bool show;
  final String message;

  factory MaintenanceInfo.fromJson(JsonReader r) => MaintenanceInfo(show: r.flag('showDialog'), message: r.text('showMessage'));
}

class ConfigCountry {
  const ConfigCountry({
    required this.id,
    required this.name,
    this.phoneCode = '',
    this.isoCode = '',
    this.minPhone = 0,
    this.maxPhone = 0,
  });

  final String id; // sent as country_id
  final String name;
  final String phoneCode;
  final String isoCode;
  final int minPhone;
  final int maxPhone;

  /// "+91" whether the API sends "91" or "+91".
  String get dial => phoneCode.isEmpty ? '' : (phoneCode.startsWith('+') ? phoneCode : '+$phoneCode');

  /// 🇮🇳 from the 2-letter ISO code ('' when unknown).
  String get flag {
    final c = isoCode.toUpperCase();
    if (c.length != 2) return '';
    return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 65));
  }

  factory ConfigCountry.fromJson(JsonReader r) => ConfigCountry(
    id: r.str('id') ?? '',
    name: r.text('name'),
    phoneCode: r.text('phonecode'),
    isoCode: r.str('isoCode') ?? r.text('countryCode'),
    minPhone: r.integer('minNumPhone') ?? 0,
    maxPhone: r.integer('maxNumPhone') ?? 0,
  );
}

class ConfigSegment {
  const ConfigSegment({required this.id, required this.name});

  final String id;
  final String name;

  factory ConfigSegment.fromJson(JsonReader r) => ConfigSegment(id: r.str('id') ?? '', name: r.text('name'));
}

/// The parts of the configuration response the app uses. Later steps add fields here
/// (countries and segments for signup, map key …).
class AppConfig {
  const AppConfig({
    this.languages = const [],
    this.cmsPages = const [],
    this.signupEnabled = false,
    this.defaultLanguage = '',
    this.logoUrl = '',
    this.supportMail = '',
    this.supportPhone = '',
    this.update = const UpdateInfo(),
    this.maintenance = const MaintenanceInfo(),
    this.orderNotificationNonStop = false,
    this.availabilityModule = false,
    this.packagingModule = false,
    this.posEnabled = false,
    this.countries = const [],
    this.segments = const [],
    this.sponsorOnSignup = false,
  });

  final List<ConfigLanguage> languages;
  final List<CmsPage> cmsPages;
  final bool signupEnabled;
  final String defaultLanguage;
  final String logoUrl;
  final String supportMail;
  final String supportPhone;
  final UpdateInfo update;
  final MaintenanceInfo maintenance;
  final bool orderNotificationNonStop;
  final bool availabilityModule;
  final bool packagingModule;
  final bool posEnabled;
  final List<ConfigCountry> countries;
  final List<ConfigSegment> segments;
  final bool sponsorOnSignup;

  CmsPage? cmsPageLike(String word) {
    for (final p in cmsPages) {
      if (p.slug.toLowerCase().contains(word)) return p;
    }
    return null;
  }

  /// Only languages this app can really show (a Material locale and strings exist).
  List<ConfigLanguage> get supportedLanguages =>
      [for (final l in languages) if (AppLanguages.find(l.locale) != null) l];

  String? languageName(String code) {
    for (final l in languages) {
      if (l.locale == code) return l.name;
    }
    return null;
  }

  factory AppConfig.fromJson(JsonReader r) {
    final general = r.sub('generalConfig');
    return AppConfig(
      languages: r.list('languages', ConfigLanguage.fromJson),
      cmsPages: r.list('storeCmsPages', CmsPage.fromJson),
      signupEnabled: general.flag('businessSegmentSignupEnable'),
      defaultLanguage: general.text('defaultLanguage'),
      logoUrl: r.str('businessLogo') ?? general.text('logoMain'),
      supportMail: r.sub('customerSupport').text('mail'),
      supportPhone: r.sub('customerSupport').text('phone'),
      update: UpdateInfo.fromJson(r.sub('appVersion')),
      maintenance: MaintenanceInfo.fromJson(r.sub('appMaintainance')), // the API spells it this way
      orderNotificationNonStop: r.flag('orderNotificationNonStop'),
      availabilityModule: r.flag('productAvailabilityTimeModuleInStore'),
      packagingModule: r.flag('packagingPreferenceInStore'),
      posEnabled: r.flag('posModuleEnable'),
      countries: r.list('countries', ConfigCountry.fromJson),
      segments: r.list('segmentData', ConfigSegment.fromJson),
      sponsorOnSignup: r.flag('sponsorDetailOnSignup'),
    );
  }
}