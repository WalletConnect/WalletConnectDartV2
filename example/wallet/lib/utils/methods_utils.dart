import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/bottom_sheet/i_bottom_sheet_service.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/deep_link_handler.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/i_web3wallet_service.dart';
import 'package:walletconnect_flutter_v2_wallet/utils/constants.dart';
import 'package:walletconnect_flutter_v2_wallet/widgets/wc_connection_widget/wc_connection_model.dart';
import 'package:walletconnect_flutter_v2_wallet/widgets/wc_connection_widget/wc_connection_widget.dart';
import 'package:walletconnect_flutter_v2_wallet/widgets/wc_request_widget.dart/wc_request_widget.dart';

class MethodsUtils {
  static final web3Wallet = GetIt.I<IWeb3WalletService>().web3wallet;

  static Future<bool> requestApproval(
    String text, {
    String? title,
    String? method,
    String? chainId,
    String? address,
    required String transportType,
    List<WCConnectionModel> extraModels = const [],
    VerifyContext? verifyContext,
  }) async {
    final bottomSheetService = GetIt.I<IBottomSheetService>();
    final WCBottomSheetResult rs = (await bottomSheetService.queueBottomSheet(
          widget: WCRequestWidget(
            verifyContext: verifyContext,
            child: WCConnectionWidget(
              title: title ?? 'Approve Request',
              info: [
                WCConnectionModel(
                  title: 'Method: $method\n'
                      'Transport Type: ${transportType.toUpperCase()}\n'
                      'Chain ID: $chainId\n'
                      'Address: $address\n\n'
                      'Message:',
                  elements: [
                    text,
                  ],
                ),
                ...extraModels,
              ],
            ),
          ),
        )) ??
        WCBottomSheetResult.reject;

    return rs != WCBottomSheetResult.reject;
  }

  static void handleRedirect(
    String topic,
    Redirect? redirect, [
    String? error,
  ]) {
    debugPrint(
        '[SampleWallet] handleRedirect topic: $topic, redirect: $redirect, error: $error');
    openApp(topic, redirect, onFail: (e) {
      debugPrint('[SampleWallet] handleRedirect error $e');
      goBackModal(
        title: 'Error',
        message: error,
        success: false,
      );
    });
  }

  static void openApp(
    String topic,
    Redirect? redirect, {
    int delay = 100,
    Function(WalletConnectError? error)? onFail,
  }) async {
    await Future.delayed(Duration(milliseconds: delay));
    DeepLinkHandler.waiting.value = false;
    try {
      await web3Wallet.redirectToDapp(
        topic: topic,
        redirect: redirect,
      );
    } on WalletConnectError catch (e) {
      onFail?.call(e);
    }
  }

  static void goBackModal({
    String? title,
    String? message,
    bool success = true,
  }) async {
    DeepLinkHandler.waiting.value = false;
    await GetIt.I<IBottomSheetService>().queueBottomSheet(
      closeAfter: success ? 3 : 0,
      widget: Container(
        color: Colors.white,
        height: 300.0,
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              success ? Icons.check_circle_sharp : Icons.error_outline_sharp,
              color: success ? Colors.green[100] : Colors.red[100],
              size: 80.0,
            ),
            Text(
              title ?? 'Connected',
              style: StyleConstants.subtitleText.copyWith(
                color: Colors.black,
                fontSize: 18.0,
              ),
            ),
            Text(message ?? 'You can go back to your dApp now'),
          ],
        ),
      ),
    );
  }
}
