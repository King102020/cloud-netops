import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud NetOps'**
  String get appTitle;

  /// No description provided for @navNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get navNetwork;

  /// No description provided for @navFirewall.
  ///
  /// In en, this message translates to:
  /// **'Firewall'**
  String get navFirewall;

  /// No description provided for @navAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get navAudit;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Control API: {baseUrl}'**
  String loginSubtitle(String baseUrl);

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'{user} · {role}'**
  String signedInAs(String user, String role);

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the control API. Is it running?'**
  String get errorNetwork;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password, or your session expired.'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'Your role cannot do this.'**
  String get errorForbidden;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict: {detail}'**
  String errorConflict(String detail);

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Not accepted: {detail}'**
  String errorValidation(String detail);

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorGeneric;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @alertsNone.
  ///
  /// In en, this message translates to:
  /// **'All systems healthy'**
  String get alertsNone;

  /// No description provided for @alertsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active alert} other{{count} active alerts}}'**
  String alertsCount(int count);

  /// No description provided for @newAlert.
  ///
  /// In en, this message translates to:
  /// **'Alert: {message}'**
  String newAlert(String message);

  /// No description provided for @alertsCleared.
  ///
  /// In en, this message translates to:
  /// **'All alerts cleared'**
  String get alertsCleared;

  /// No description provided for @topologyTitle.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get topologyTitle;

  /// No description provided for @topologyMapLabel.
  ///
  /// In en, this message translates to:
  /// **'Network map with {devices} devices and {links} links'**
  String topologyMapLabel(int devices, int links);

  /// No description provided for @deviceNodeLabel.
  ///
  /// In en, this message translates to:
  /// **'{id}, {role}, {status}'**
  String deviceNodeLabel(String id, String role, String status);

  /// No description provided for @linksTitle.
  ///
  /// In en, this message translates to:
  /// **'WAN links'**
  String get linksTitle;

  /// No description provided for @linkTitle.
  ///
  /// In en, this message translates to:
  /// **'{id} · {subnet}'**
  String linkTitle(String id, String subnet);

  /// No description provided for @linkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{a} ↔ {b} · OSPF cost {cost}'**
  String linkSubtitle(String a, String b, String cost);

  /// No description provided for @linkToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Link {id} is {state}'**
  String linkToggleLabel(String id, String state);

  /// No description provided for @stateUp.
  ///
  /// In en, this message translates to:
  /// **'up'**
  String get stateUp;

  /// No description provided for @stateDown.
  ///
  /// In en, this message translates to:
  /// **'down'**
  String get stateDown;

  /// No description provided for @stateUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get stateUnknown;

  /// No description provided for @viewOnly.
  ///
  /// In en, this message translates to:
  /// **'View only. Sign in as operator to change links and rules.'**
  String get viewOnly;

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAt(String time);

  /// No description provided for @healthHealthy.
  ///
  /// In en, this message translates to:
  /// **'healthy'**
  String get healthHealthy;

  /// No description provided for @healthDegraded.
  ///
  /// In en, this message translates to:
  /// **'degraded'**
  String get healthDegraded;

  /// No description provided for @healthDown.
  ///
  /// In en, this message translates to:
  /// **'down'**
  String get healthDown;

  /// No description provided for @deviceHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get deviceHealth;

  /// No description provided for @deviceSite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get deviceSite;

  /// No description provided for @deviceModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get deviceModel;

  /// No description provided for @deviceRouterId.
  ///
  /// In en, this message translates to:
  /// **'Router ID'**
  String get deviceRouterId;

  /// No description provided for @deviceUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get deviceUptime;

  /// No description provided for @ospfNeighbors.
  ///
  /// In en, this message translates to:
  /// **'OSPF neighbours'**
  String get ospfNeighbors;

  /// No description provided for @ospfMissing.
  ///
  /// In en, this message translates to:
  /// **'No adjacency with {routerId}'**
  String ospfMissing(String routerId);

  /// No description provided for @interfacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Interfaces'**
  String get interfacesTitle;

  /// No description provided for @noNeighbors.
  ///
  /// In en, this message translates to:
  /// **'No OSPF neighbours'**
  String get noNeighbors;

  /// No description provided for @firewallTitle.
  ///
  /// In en, this message translates to:
  /// **'Firewall rules'**
  String get firewallTitle;

  /// No description provided for @firewallEmpty.
  ///
  /// In en, this message translates to:
  /// **'No API-managed rules yet. The baseline rules from the design are always on.'**
  String get firewallEmpty;

  /// No description provided for @addRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get addRule;

  /// No description provided for @ruleSummary.
  ///
  /// In en, this message translates to:
  /// **'{protocol} {ports} from {cidr} → {site} {tier}'**
  String ruleSummary(
    String protocol,
    String ports,
    String cidr,
    String site,
    String tier,
  );

  /// No description provided for @ruleToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Rule {id} enabled'**
  String ruleToggleLabel(String id);

  /// No description provided for @deleteRule.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get deleteRule;

  /// No description provided for @deleteRuleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete rule {id}? Terraform will remove it.'**
  String deleteRuleConfirm(String id);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Applying'**
  String get statusPending;

  /// No description provided for @statusApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get statusApplied;

  /// No description provided for @statusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get statusPlanned;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @changeSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Change submitted. Terraform is running.'**
  String get changeSubmitted;

  /// No description provided for @fieldSite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get fieldSite;

  /// No description provided for @fieldTier.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get fieldTier;

  /// No description provided for @fieldProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get fieldProtocol;

  /// No description provided for @fieldFromPort.
  ///
  /// In en, this message translates to:
  /// **'From port'**
  String get fieldFromPort;

  /// No description provided for @fieldToPort.
  ///
  /// In en, this message translates to:
  /// **'To port'**
  String get fieldToPort;

  /// No description provided for @fieldCidr.
  ///
  /// In en, this message translates to:
  /// **'Source CIDR'**
  String get fieldCidr;

  /// No description provided for @fieldCidrHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 10.20.10.0/24'**
  String get fieldCidrHint;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @invalidPort.
  ///
  /// In en, this message translates to:
  /// **'1–65535'**
  String get invalidPort;

  /// No description provided for @invalidPortRange.
  ///
  /// In en, this message translates to:
  /// **'From must be ≤ to'**
  String get invalidPortRange;

  /// No description provided for @invalidCidr.
  ///
  /// In en, this message translates to:
  /// **'Private IPv4 network, e.g. 10.20.10.0/24'**
  String get invalidCidr;

  /// No description provided for @worldOpen.
  ///
  /// In en, this message translates to:
  /// **'0.0.0.0/0 is not allowed (default deny)'**
  String get worldOpen;

  /// No description provided for @invalidDescription.
  ///
  /// In en, this message translates to:
  /// **'3–200 characters: letters, digits, space . , : / ( ) + -'**
  String get invalidDescription;

  /// No description provided for @auditTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get auditTitle;

  /// No description provided for @auditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No changes recorded yet.'**
  String get auditEmpty;

  /// No description provided for @auditEntry.
  ///
  /// In en, this message translates to:
  /// **'{actor} · {action} · {target}'**
  String auditEntry(String actor, String action, String target);

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
