import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PrivacyPolicyPage extends StatefulWidget {
  final String privacyPolicyUrl = 'https://macabenlar.github.io/Reading-With-PHIL-IRI/'; // Replace with your URL

  @override
  _PrivacyPolicyPageState createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  bool isLoading = true; // Flag to track loading state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Privacy Policy")),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.privacyPolicyUrl)),
            onWebViewCreated: (InAppWebViewController controller) {
              // Do something when WebView is created
            },
            onLoadStart: (InAppWebViewController controller, Uri? url) {
              // Show loading indicator when page starts loading
              setState(() {
                isLoading = true;
              });
            },
            onLoadStop: (InAppWebViewController controller, Uri? url) {
              // Hide loading indicator when page finishes loading
              setState(() {
                isLoading = false;
              });
            },
          ),
          isLoading
              ? Center(
                  child: CircularProgressIndicator(), // Show indicator while loading
                )
              : SizedBox.shrink(), // Hide indicator when loading is done
        ],
      ),
    );
  }
}
