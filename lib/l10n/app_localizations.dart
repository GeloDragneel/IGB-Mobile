import 'package:flutter/material.dart';
import 'app_en.dart';
import 'app_zh.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String> get _translations {
    switch (locale.languageCode) {
      case 'zh':
        return AppZh.translations;
      case 'en':
      default:
        return AppEn.translations;
    }
  }

  String translate(String key) {
    return _translations[key] ?? key;
  }

  String formatDate(DateTime date) {
    if (locale.languageCode == 'zh') {
      return '${date.year}年${date.month}月${date.day}日';
    }
    final monthKeys = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final monthName = translate(monthKeys[date.month - 1]);
    return '$monthName ${date.day}, ${date.year}';
  }

  // Convenience getters for common translations
  String get appName => translate('app_name');
  String get dashboard => translate('dashboard');
  String get messages => translate('messages');
  String get sales => translate('sales');
  String get purchases => translate('purchases');
  String get expenses => translate('expenses');
  String get reports => translate('reports');
  String get profile => translate('profile');
  String get accountingPeriod => translate('accounting_period');
  String get enableBiometric => translate('enable_biometric');
  String get logout => translate('logout');
  String get chatListTitle => translate('chat_list_title');
  String get noConversations => translate('no_conversations');
  String get startNewChat => translate('start_new_chat');
  String get newChat => translate('new_chat');
  String get enterChatName => translate('enter_chat_name');
  String get cancel => translate('cancel');
  String get create => translate('create');
  String get deleteChat => translate('delete_chat');
  String get deleteChatConfirmation => translate('delete_chat_confirmation');
  String get deleteRecordConfirmation => translate('deleteRecordConfirmation');
  String get delete => translate('delete');
  String get deleteRecord => translate('deleteRecord');
  String get chatInfo => translate('chat_info');
  String get mute => translate('mute');
  String get search => translate('search');
  String get wallpaper => translate('wallpaper');
  String get participants => translate('participants');
  String get noMessages => translate('no_messages');
  String get startConversation => translate('start_conversation');
  String get typeMessage => translate('type_message');
  String get welcome => translate('welcome');
  String get totalSales => translate('total_sales');
  String get totalPurchases => translate('total_purchases');
  String get totalExpenses => translate('total_expenses');
  String get netIncome => translate('net_income');
  String get loading => translate('loading');
  String get error => translate('error');
  String get success => translate('success');
  String get save => translate('save');
  String get edit => translate('edit');
  String get update => translate('update');
  String get confirm => translate('confirm');
  String get yes => translate('yes');
  String get no => translate('no');
  String get ok => translate('ok');
  String get close => translate('close');
  String get back => translate('back');
  String get next => translate('next');
  String get done => translate('done');
  String get retry => translate('retry');
  String get refresh => translate('refresh');
  String get language => translate('language');
  String get english => translate('english');
  String get chinese => translate('chinese');
  String get switchLanguage => translate('switch_language');
  String get currentLanguage => translate('current_language');
  String get languageSettings => translate('languageSettings');
  String get profileSettings => translate('profile_settings');
  String get accountSettings => translate('account_settings');
  String get appSettings => translate('app_settings');
  String get notifications => translate('notifications');
  String get privacy => translate('privacy');
  String get help => translate('help');
  String get about => translate('about');
  String get version => translate('version');
  String get login => translate('login');
  String get logoutConfirm => translate('logout_confirm');
  String get username => translate('username');
  String get password => translate('password');
  String get rememberMe => translate('remember_me');
  String get forgotPassword => translate('forgot_password');
  String get salesScreen => translate('sales_screen');
  String get addSale => translate('add_sale');
  String get saleDetails => translate('sale_details');
  String get saleAmount => translate('sale_amount');
  String get saleDate => translate('sale_date');
  String get customer => translate('customer');
  String get invoiceNumber => translate('invoice_number');
  String get purchasesScreen => translate('purchases_screen');
  String get addPurchase => translate('add_purchase');
  String get purchaseDetails => translate('purchase_details');
  String get purchaseAmount => translate('purchase_amount');
  String get purchaseDate => translate('purchase_date');
  String get supplier => translate('supplier');
  String get receiptNumber => translate('receipt_number');
  String get expensesScreen => translate('expenses_screen');
  String get addExpense => translate('add_expense');
  String get expenseDetails => translate('expense_details');
  String get expenseAmount => translate('expense_amount');
  String get expenseDate => translate('expense_date');
  String get category => translate('category');
  String get description => translate('description');
  String get reportsScreen => translate('reports_screen');
  String get generateReport => translate('generate_report');
  String get reportType => translate('report_type');
  String get dateRange => translate('date_range');
  String get fromDate => translate('from_date');
  String get toDate => translate('to_date');
  String get export => translate('export');
  String get print => translate('print');
  String get share => translate('share');
  String get revenueOverview => translate('revenueOverview');
  String get last6Months => translate('last6Months');
  String get monthlySales => translate('monthlySales');
  String get barChart => translate('barChart');
  String get costBreakdown => translate('costBreakdown');
  String get purchasesVsExpenses => translate('purchasesVsExpenses');
  String get monthlyPurchases => translate('monthlyPurchases');
  String get monthlyExpenses => translate('monthlyExpenses');
  String get goodMorning => translate('goodMorning');
  String get goodAfternoon => translate('goodAfternoon');
  String get goodEvening => translate('goodEvening');
  String get businessOverview => translate('businessOverview');
  String get bought => translate('bought');
  String get spent => translate('spent');
  String get customers => translate('customers');
  String get active => translate('active');
  String get activeNow => translate('activeNow');
  String get vendors => translate('vendors');
  String get partners => translate('partners');
  String get scanned => translate('scanned');
  String get qrCodes => translate('qrCodes');
  String get jan => translate('jan');
  String get feb => translate('feb');
  String get mar => translate('mar');
  String get apr => translate('apr');
  String get may => translate('may');
  String get jun => translate('jun');
  String get jul => translate('jul');
  String get aug => translate('aug');
  String get sep => translate('sep');
  String get oct => translate('oct');
  String get nov => translate('nov');
  String get dec => translate('dec');
  String get today => translate('today');
  String get yesterday => translate('yesterday');
  String get daysAgo => translate('daysAgo');
  String get weeksAgo => translate('weeksAgo');
  String get salesInvoices => translate('salesInvoices');
  String get scan => translate('scan');
  String get searchByFilename => translate('searchByFilename');
  String get total => translate('total');
  String get pending => translate('pending');
  String get confirmed => translate('confirmed');
  String get invalid => translate('invalid');
  String get partiallyInvalid => translate('partiallyInvalid');
  String get noRecordFound => translate('noRecordFound');
  String get ref => translate('ref');
  String get viewReceipt => translate('viewReceipt');
  String get page => translate('page');
  String get of_ => translate('of_');
  String get somethingWentWrong => translate('somethingWentWrong');
  String get noDataFound => translate('noDataFound');
  String get all => translate('all');
  String get addAnotherReceipt => translate('addAnotherReceipt');
  String get doYouWantAnotherReceipt => translate('doYouWantAnotherReceipt');
  String get addMore => translate('addMore');
  String get ocrFailed => translate('ocrFailed');
  String get nextReceipt => translate('nextReceipt');
  String get receiptUploadSuccess => translate('receiptUploadSuccess');
  String get uploadFromDevices => translate('uploadFromDevices');
  String get processingImage => translate('processingImage');
  String get uploading => translate('uploading');
  String get scannedImages => translate('scannedImages');
  String get submitReceipts => translate('submitReceipts');
  String get recordDeletedSuccess => translate('recordDeletedSuccess');
  String get failedToDeleteRecord => translate('failedToDeleteRecord');
  String get searchByCodeOrName => translate('searchByCodeOrName');
  String get noAccountsFound => translate('noAccountsFound');
  String get selectExpenseAccount => translate('selectExpenseAccount');
  String get searchReport => translate('searchReport');
  String get trialBalance => translate('trial_balance');
  String get summary => translate('summary');
  String get generalLedger => translate('general_ledger');
  String get customerLedger => translate('customer_ledger');
  String get eBir => translate('e_bir');
  String get consolidatedReportDetailed =>
      translate('consolidated_report_detailed');
  String get purchaseReport => translate('purchase_report');
  String get salesReport => translate('sales_report');
  String get expenseReport => translate('expense_report');
  String get importReport => translate('import_report');
  String get eSubReport => translate('e_sub_report');
  String get bir2307 => translate('bir2307');
  String get incomeStatement => translate('income_statement');
  String get annualSummary => translate('annual_summary');
  String get annualSummaryComparative =>
      translate('annual_summary_comparative');
  String get salesJournal => translate('sales_journal');
  String get purchaseReceiptsJournal => translate('purchase_receipts_journal');
  String get cashDisbursementJournal => translate('cash_disbursement_journal');
  String get transactions => translate('transactions');
  String get accountPayable => translate('account_payable');
  String get accountReceivable => translate('account_receivable');
  String get fullname => translate('fullname');
  String get personalInformation => translate('personalInformation');
  String get businessInformation => translate('businessInformation');
  String get tradeName => translate('tradeName');
  String get branchCode => translate('branchCode');
  String get branchType => translate('branchType');
  String get clientNumber => translate('clientNumber');
  String get tin => translate('tin');
  String get documents => translate('documents');
  String get changeUploadImage => translate('changeUploadImage');
  String get pleaseSelectBothDates => translate('pleaseSelectBothDates');
  String get sessionCreated => translate('sessionCreated');
  String get accountPeriod => translate('accountPeriod');
  String get dateFrom => translate('dateFrom');
  String get dateTo => translate('dateTo');
  String get createSesion => translate('createSesion');
  String get biometricAuthentificationNotAvail =>
      translate('biometricAuthentificationNotAvail');
  String get pleaseLoginFirst => translate('pleaseLoginFirst');
  String get fingerprintRegisteredSuccess =>
      translate('fingerprintRegisteredSuccess');
  String get biometricAlreadyRegistered =>
      translate('biometricAlreadyRegistered');
  String get registrationFailed => translate('registrationFailed');
  String get serverError => translate('serverError');
  String get fingerprintRegistered => translate('fingerprintRegistered');
  String get notRegistered => translate('notRegistered');
  String get yourFingerPrintIsActive => translate('yourFingerPrintIsActive');
  String get tapToRegisterYourFingerPrint =>
      translate('tapToRegisterYourFingerPrint');
  String get registerFingerprint => translate('registerFingerprint');
  String get noBiometricRegistered => translate('noBiometricRegistered');
  String get invalidCredentials => translate('invalidCredentials');
  String get biometricLoginSuccess => translate('biometricLoginSuccess');
  String get loginFailed => translate('loginFailed');
  String get authenticationError => translate('authenticationError');
  String get selectAccount => translate('selectAccount');
  String get chooseAnAccountToContinueWith =>
      translate('chooseAnAccountToContinueWith');
  String get welcomeBack => translate('welcomeBack');
  String get signinToContinueToYourAccount =>
      translate('signinToContinueToYourAccount');
  String get enterYourUsername => translate('enterYourUsername');
  String get enterYourPassword => translate('enterYourPassword');
  String get required => translate('required');
  String get invalidUserOrPass => translate('invalidUserOrPass');
  String get passwordResetRequired => translate('passwordResetRequired');
  String get duplicateUserDetected => translate('duplicateUserDetected');
  String get tooManyAttempts => translate('tooManyAttempts');
  String get invalidScanAccess => translate('invalidScanAccess');
  String get loginError => translate('loginError');
  String get signin => translate('signin');
  String get registerFingerprintViaEnable =>
      translate('registerFingerprintViaEnable');
  String get groups => translate('groups');
  String get messageStaff => translate('messageStaff');
  String get messageColleague => translate('messageColleague');
  String get noConversationYet => translate('noConversationYet');
  String get startANewChat => translate('startANewChat');
  String get noMessagesYet => translate('noMessagesYet');
  String get you => translate('you');
  String get youSentAnAttachment => translate('youSentAnAttachment');
  String get sentAnAttachment => translate('sentAnAttachment');
  String get justNow => translate('justNow');
  String get attachment => translate('attachment');
  String get file => translate('file');
  String get members => translate('members');
  String get addMembers => translate('members');
  String get leaveGroup => translate('leaveGroup');
  String get admin => translate('admin');
  String get addedBy => translate('addedBy');
  String get leaveConfirmation => translate('leaveConfirmation');
  String get youLeftTheGroup => translate('youLeftTheGroup');
  String get leave => translate('leave');
  String get tapForGroupInfo => translate('tapForGroupInfo');
  String get startTheGroupConversation =>
      translate('startTheGroupConversation');
  String get messageGroup => translate('messageGroup');
  String get membersAddedSuccessfully => translate('membersAddedSuccessfully');
  String get failedAddMember => translate('failedAddMember');
  String get add => translate('add');
  String get noUsersAvailableToAdd => translate('noUsersAvailableToAdd');
  String get createGroup => translate('createGroup');
  String get groupName => translate('groupName');
  String get addAtleastOneMember => translate('addAtleastOneMember');
  String get groupCrated => translate('groupCrated');
  String get logoutConfirmation => translate('logoutConfirmation');
  String get dAgo => translate('dAgo');
  String get hAgo => translate('hAgo');
  String get mAgo => translate('mAgo');
  String get tapPlusToCreateAGroup => translate('tapPlusToCreateAGroup');
  String get youWillAppearHereOnceAddedToAGroup =>
      translate('youWillAppearHereOnceAddedToAGroup');
  String get noGroupsYet => translate('noGroupsYet');
  String get resetZoom => translate('resetZoom');
  String get accountCode => translate('accountCode');
  String get accountName => translate('accountName');
  String get debit => translate('debit');
  String get credit => translate('credit');
  String get generatingSummaryFrom => translate('generatingSummaryFrom');
  String get to => translate('to');
  String get reset => translate('reset');
  String get date => translate('date');
  String get reference => translate('reference');
  String get jrnl => translate('jrnl');
  String get transDecription => translate('transDecription');
  String get balance => translate('balance');
  String get vendor => translate('vendor');
  String get scanTips => translate('scanTips');
  String get previewTips => translate('previewTips');
  String get scanYourDocuments => translate('scanYourDocuments');
  String get alignYourReceipt => translate('alignYourReceipt');
  String get amount => translate('amount');
  String get currency => translate('currency');
  String get exRate => translate('exRate');
  String get netVAT => translate('netVAT');
  String get inputVAT => translate('inputVAT');
  String get vatExempt => translate('vatExempt');
  String get zeroRated => translate('zeroRated');
  String get nonVAT => translate('nonVAT');
  String get summaryOfSalesVtPt => translate('summaryOfSalesVtPt');
  String get summaryOfSalesIT => translate('summaryOfSalesIT');
  String get summaryOfPEIT => translate('summaryOfPEIT');
  String get selectReportType => translate('selectReportType');
  String get accountId => translate('accountId');
  String get tran => translate('tran');
  String get name => translate('name');
  String get lineDescription => translate('lineDescription');
  String get invoiceCMNo => translate('invoiceCMNo');
  String get pleaseSelectJournalAndYear =>
      translate('pleaseSelectJournalAndYear');
  String get selectYear => translate('selectYear');
  String get selectJournal => translate('selectJournal');
  String get purchaseJournal => translate('purchaseJournal');
  String get expensesJournal => translate('expensesJournal');
  String get accountsPayable => translate('accountsPayable');
  String get accountsReceivable => translate('accountsReceivable');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
