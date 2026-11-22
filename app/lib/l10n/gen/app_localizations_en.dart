// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cloud NetOps';

  @override
  String get navNetwork => 'Network';

  @override
  String get navFirewall => 'Firewall';

  @override
  String get navAudit => 'Audit log';

  @override
  String get loginTitle => 'Sign in';

  @override
  String loginSubtitle(String baseUrl) {
    return 'Control API: $baseUrl';
  }

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get fieldRequired => 'Required';

  @override
  String signedInAs(String user, String role) {
    return '$user · $role';
  }

  @override
  String get errorNetwork => 'Cannot reach the control API. Is it running?';

  @override
  String get errorUnauthorized =>
      'Wrong username or password, or your session expired.';

  @override
  String get errorForbidden => 'Your role cannot do this.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Wait a minute and try again.';

  @override
  String errorConflict(String detail) {
    return 'Conflict: $detail';
  }

  @override
  String errorValidation(String detail) {
    return 'Not accepted: $detail';
  }

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading';

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get alertsNone => 'All systems healthy';

  @override
  String alertsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active alerts',
      one: '1 active alert',
    );
    return '$_temp0';
  }

  @override
  String newAlert(String message) {
    return 'Alert: $message';
  }

  @override
  String get alertsCleared => 'All alerts cleared';

  @override
  String get topologyTitle => 'Network';

  @override
  String topologyMapLabel(int devices, int links) {
    return 'Network map with $devices devices and $links links';
  }

  @override
  String deviceNodeLabel(String id, String role, String status) {
    return '$id, $role, $status';
  }

  @override
  String get linksTitle => 'WAN links';

  @override
  String linkTitle(String id, String subnet) {
    return '$id · $subnet';
  }

  @override
  String linkSubtitle(String a, String b, String cost) {
    return '$a ↔ $b · OSPF cost $cost';
  }

  @override
  String linkToggleLabel(String id, String state) {
    return 'Link $id is $state';
  }

  @override
  String get stateUp => 'up';

  @override
  String get stateDown => 'down';

  @override
  String get stateUnknown => 'unknown';

  @override
  String get viewOnly =>
      'View only. Sign in as operator to change links and rules.';

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String get healthHealthy => 'healthy';

  @override
  String get healthDegraded => 'degraded';

  @override
  String get healthDown => 'down';

  @override
  String get deviceHealth => 'Health';

  @override
  String get deviceSite => 'Site';

  @override
  String get deviceModel => 'Model';

  @override
  String get deviceRouterId => 'Router ID';

  @override
  String get deviceUptime => 'Uptime';

  @override
  String get ospfNeighbors => 'OSPF neighbours';

  @override
  String ospfMissing(String routerId) {
    return 'No adjacency with $routerId';
  }

  @override
  String get interfacesTitle => 'Interfaces';

  @override
  String get noNeighbors => 'No OSPF neighbours';

  @override
  String get firewallTitle => 'Firewall rules';

  @override
  String get firewallEmpty =>
      'No API-managed rules yet. The baseline rules from the design are always on.';

  @override
  String get addRule => 'Add rule';

  @override
  String ruleSummary(
    String protocol,
    String ports,
    String cidr,
    String site,
    String tier,
  ) {
    return '$protocol $ports from $cidr → $site $tier';
  }

  @override
  String ruleToggleLabel(String id) {
    return 'Rule $id enabled';
  }

  @override
  String get deleteRule => 'Delete rule';

  @override
  String deleteRuleConfirm(String id) {
    return 'Delete rule $id? Terraform will remove it.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get statusPending => 'Applying';

  @override
  String get statusApplied => 'Applied';

  @override
  String get statusPlanned => 'Planned';

  @override
  String get statusFailed => 'Failed';

  @override
  String get changeSubmitted => 'Change submitted. Terraform is running.';

  @override
  String get fieldSite => 'Site';

  @override
  String get fieldTier => 'Tier';

  @override
  String get fieldProtocol => 'Protocol';

  @override
  String get fieldFromPort => 'From port';

  @override
  String get fieldToPort => 'To port';

  @override
  String get fieldCidr => 'Source CIDR';

  @override
  String get fieldCidrHint => 'e.g. 10.20.10.0/24';

  @override
  String get fieldDescription => 'Description';

  @override
  String get invalidPort => '1–65535';

  @override
  String get invalidPortRange => 'From must be ≤ to';

  @override
  String get invalidCidr => 'Private IPv4 network, e.g. 10.20.10.0/24';

  @override
  String get worldOpen => '0.0.0.0/0 is not allowed (default deny)';

  @override
  String get invalidDescription =>
      '3–200 characters: letters, digits, space . , : / ( ) + -';

  @override
  String get auditTitle => 'Audit log';

  @override
  String get auditEmpty => 'No changes recorded yet.';

  @override
  String auditEntry(String actor, String action, String target) {
    return '$actor · $action · $target';
  }

  @override
  String get loadMore => 'Load more';
}
