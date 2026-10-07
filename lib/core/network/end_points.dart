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
  static const getOrders = 'api/business-segment/get-orders';
  static const getOrderDetails = 'api/business-segment/get-order-details';
  static const acceptOrder = 'api/business-segment/accept-order';
  static const processOrder = 'api/business-segment/process-order';
  static const rejectOrder = 'api/business-segment/reject-order';
  static const orderReady = 'api/business-segment/order-ready';
  static const deliverOrder = 'api/business-segment/deliver-order';
  static const autoAssignDriver = 'api/business-segment/auto-assign-driver';
  static const manualAssignDriver = 'api/business-segment/manual-assign-driver';
  static const getDrivers = 'api/business-segment/get-drivers';
  static const pickupOtpVerification = 'api/business-segment/pickup-order-otp-verification';

  /// Requests that are sent with publicKey / secretKey even when a token exists (Jetpack rule).
  static const publicKeyEndpoints = [appStrings,previewLogin];
}