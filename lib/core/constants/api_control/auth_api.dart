import 'global_api.dart';

class AuthAPIController {
 static final String _base_api = "$api/api";
 static String login = "$_base_api/login";
  static String registerTypeSelection = "$_base_api/register-type";
  static String registerName= "$_base_api/register-name";
  static String registerPhone= "$_base_api/register-phone";
  static String registerEmail= "$_base_api/register-email";
  static String registerVendorRequestStore= "$_base_api/vendor/register";
  static String business_type= "$_base_api/business-type";
  /// Zone / state / town lists for vendor & driver register (visibility-locations).
  static String get registerLocationZones =>
      '$_base_api/buyer/visibility-locations/zones';
  static String registerLocationStates({required String zone}) => Uri.parse(
        '$_base_api/buyer/visibility-locations/states',
      ).replace(queryParameters: {'zone': zone.trim()}).toString();
  static String registerLocationTowns({
    required String zone,
    required String state,
  }) =>
      Uri.parse('$_base_api/buyer/visibility-locations/towns').replace(
        queryParameters: {
          'zone': zone.trim(),
          'state': state.trim(),
        },
      ).toString();
  static String registerDriverCarInfo="$_base_api/driver/register";
  static String phoneVerifyOtp="$_base_api/user-verify-otp";
  static String resetPassword="$_base_api/reset-password";
  static String registerPassword="$_base_api/register-password";
  static String forgetPassword="$_base_api/forget-password";
  static String verifyOtp="$_base_api/verify-mail-otp";
  static String route="$_base_api/route";
  static String user_show = "$_base_api/user/show";

  /// POLISH — includes `modules.transport` (fallback: [user_show]).
  static String userDetail({String? id}) {
    if (id == null || id.trim().isEmpty) {
      return '$_base_api/user/detail';
    }
    return Uri.parse('$_base_api/user/detail')
        .replace(queryParameters: {'id': id.trim()})
        .toString();
  }

  static String vendor_show = "$_base_api/vendor/show";
}
