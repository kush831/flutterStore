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
  static const getProducts = 'api/business-segment/get-products';
  static const updateProductStatus = 'api/business-segment/update-product-status';
  static const merchantCategories = 'api/business-segment/get-merchant-categories';
  static const productStep1 = 'api/business-segment/get-product-step1';
  static const saveProductStep1 = 'api/business-segment/save-product-step1';
  static const subCategories = 'api/business-segment/get-sub-categories';
  static const productStep2 = 'api/business-segment/get-product-step2';
  static const saveProductStep2 = 'api/business-segment/save-product-step2';
  static const productStep3 = 'api/business-segment/get-product-step3';
  static const saveProductStep3 = 'api/business-segment/save-product-step3';
  static const productDetails = 'api/business-segment/get-product-details';
  static const productOptions = 'api/business-segment/get-product-options';
  static const saveOptions = 'api/business-segment/save-options';

  static const getOptions = 'api/business-segment/get-options';
  static const optionTypes = 'api/business-segment/get-options-types';
  static const saveOption = 'api/business-segment/add-option'; // also updates, when an `id` is sent
  static const deleteOption = 'api/business-segment/delete-option';

  static const merchantDetails = 'api/business-segment/get-merchant-details';
  static const editProfile = 'api/business-segment/edit-profile';

  static const timeSlabs = 'api/business-segment/product-availability-time-slabs';
  static const saveSlab = 'api/business-segment/product-availability-time-slabs/save';
  static const deleteSlab = 'api/business-segment/product-availability-time-slabs/delete';
  static const earnings = 'api/business-segment/get-earnings';
  static const walletTransactions = 'api/business-segment/get-wallet-transactions';
  static const cashoutTransactions = 'api/business-segment/get-cashout-transactions';
  static const requestCashout = 'api/business-segment/request-cashout';
  static const logout = 'api/business-segment/out-board';
  static const deleteAccount = 'api/business-segment/delete-account';
  static const membershipPlans = 'api/business-segment/membership-plan';
  static const buyMembership = 'api/business-segment/purchase-membership-plan';
  /// Requests that are sent with publicKey / secretKey even when a token exists (Jetpack rule).
  static const publicKeyEndpoints = [appStrings,previewLogin];
}