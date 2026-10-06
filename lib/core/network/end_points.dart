/// Every step adds the endpoints it needs. Paths are relative to BASE_URL.
abstract final class EndPoints {
  static const login = 'api/business-segment/on-board';
  static const configuration = 'api/business-segment/configuration';
  static const appStrings = 'api/v1/appstrings/STORE';
  static const previewLogin = 'api/get-secret-keys';
  static const signup = 'api/business-segment/signup';
  static const forgotPasswordRequest = 'api/business-segment/reset-password';
  static const resetPassword = 'api/business-segment/forgot-password';
  static const cmsPages = 'api/business-segment/cms/pages';
  static const loginAsDemo = 'api/business-segment/login-details';
  static const stripeRequiredDetails = 'api/business-segment/get-stripe-connect-required-details';
  static const stripeSubmit = 'api/business-segment/register-stripe-connect';
  static const uploadDocumentTypes = 'api/business-segment/get-stripe-connect-require-document';
  static const uploadDocumentImages = 'api/business-segment/upload-stripe-connect-document';
  static const homeScreen = 'api/business-segment/home-screen';
  static const orderStatistics = 'api/business-segment/get-order-statistics';
  static const updateStoreStatus = 'api/business-segment/update-store-status';

  /// Requests that are sent with publicKey / secretKey even when a token exists (Jetpack rule).
  static const publicKeyEndpoints = [appStrings];
}