import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/i_web3wallet_service.dart';
import 'package:walletconnect_flutter_v2_wallet/utils/constants.dart';
import 'package:walletconnect_flutter_v2_wallet/utils/namespace_model_builder.dart';
import 'package:walletconnect_flutter_v2_wallet/utils/string_constants.dart';
import 'package:walletconnect_flutter_v2_wallet/widgets/custom_button.dart';
import 'package:walletconnect_flutter_v2_wallet/widgets/wc_connection_widget/wc_connection_widget.dart';

class AppDetailPage extends StatefulWidget {
  final PairingInfo pairing;

  const AppDetailPage({
    super.key,
    required this.pairing,
  });

  @override
  AppDetailPageState createState() => AppDetailPageState();
}

class AppDetailPageState extends State<AppDetailPage> {
  @override
  Widget build(BuildContext context) {
    DateTime dateTime =
        DateTime.fromMillisecondsSinceEpoch(widget.pairing.expiry * 1000);
    int year = dateTime.year;
    int month = dateTime.month;
    int day = dateTime.day;

    String expiryDate =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    List<SessionData> sessions = GetIt.I
        .get<IWeb3WalletService>()
        .getWeb3Wallet()
        .sessions
        .getAll()
        .where((element) => element.pairingTopic == widget.pairing.topic)
        .toList();

    List<Widget> sessionWidgets = [];
    for (final SessionData session in sessions) {
      List<Widget> namespaceWidget =
          ConnectionWidgetBuilder.buildFromNamespaces(
        session.topic,
        session.namespaces,
      );
      // Loop through and add the namespace widgets, but put 20 pixels between each one
      for (int i = 0; i < namespaceWidget.length; i++) {
        sessionWidgets.add(namespaceWidget[i]);
        if (i != namespaceWidget.length - 1) {
          sessionWidgets.add(const SizedBox(height: 20.0));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pairing.peerMetadata?.name ?? 'Unknown'),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(
            StyleConstants.linear8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: CircleAvatar(
                  backgroundImage: (widget
                              .pairing.peerMetadata!.icons.isNotEmpty
                          ? NetworkImage(widget.pairing.peerMetadata!.icons[0])
                          : const AssetImage('assets/images/default_icon.png'))
                      as ImageProvider<Object>,
                ),
              ),
              const SizedBox(height: 20.0),
              Text(
                widget.pairing.peerMetadata!.name,
                style: StyleConstants.subtitleText,
              ),
              const SizedBox(height: 20.0),
              Text(widget.pairing.peerMetadata!.url),
              Text('Expires on: $expiryDate'),
              const SizedBox(height: 20.0),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: sessionWidgets,
              ),
              const SizedBox(height: 20.0),
              Row(
                children: [
                  CustomButton(
                    type: CustomButtonType.invalid,
                    onTap: () async {
                      try {
                        await GetIt.I<IWeb3WalletService>()
                            .getWeb3Wallet()
                            .core
                            .pairing
                            .disconnect(topic: widget.pairing.topic);
                        _back();
                      } catch (e) {
                        //debugPrint(e.toString());
                      }
                    },
                    child: const Center(
                      child: Text(StringConstants.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _back() {
    Navigator.of(context).pop();
  }

  // void _onPingTap() {
  //   GetIt.I<IWeb3WalletService>().getWeb3Wallet().ping web3Wallet.core.pairing.ping(
  //     topic: pairing.topic,
  //   );
  // }
}

// () async {
            //   showDialog(
            //     context: context,
            //     builder: (BuildContext context) {
            //       return AlertDialog(
            //         title: const Text(
            //           StringConstants.deletePairing,
            //           style: StyleConstants.titleText,
            //         ),
            //         content: Text(
            //           pairing.topic,
            //         ),
            //         actions: [
            //           TextButton(
            //             child: const Text(
            //               StringConstants.cancel,
            //             ),
            //             onPressed: () {
            //               Navigator.of(context).pop();
            //             },
            //           ),
            //           TextButton(
            //             child: const Text(
            //               StringConstants.delete,
            //             ),
            //             onPressed: () async {
            //               try {
            //                 web3Wallet.core.pairing.disconnect(
            //                   topic: pairing.topic,
            //                 );
            //                 Navigator.of(context).pop();
            //               } catch (e) {
            //                 //debugPrint(e.toString());
            //               }
            //             },
            //           ),
            //         ],
            //       );
            //     },
            //   );
            // },