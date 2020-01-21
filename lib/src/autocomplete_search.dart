import 'dart:async';

import 'package:google_maps_place_picker/providers/place_provider.dart';
import 'package:google_maps_place_picker/providers/search_provider.dart';
import 'package:google_maps_place_picker/src/components/prediction_tile.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_place_picker/src/components/rounded_frame.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:provider/provider.dart';

class AutoCompleteSearch extends StatefulWidget {
  const AutoCompleteSearch({
    Key key,
    @required this.sessionToken,
    @required this.appBarKey,
    @required this.onPicked,
    this.searchBarDecoration,
    this.hintText,
    this.searchingText = "Searching...",
    this.height = 40,
    this.contentPadding = EdgeInsets.zero,
    this.debounceMilliseconds = 750,
    this.onSearchFailed,
  }) : super(key: key);

  final String sessionToken;
  final GlobalKey appBarKey;
  final Decoration searchBarDecoration;
  final String hintText;
  final String searchingText;
  final double height;
  final EdgeInsetsGeometry contentPadding;
  final int debounceMilliseconds;
  final ValueChanged<Prediction> onPicked;
  final ValueChanged<String> onSearchFailed;

  @override
  _AutoCompleteSearchState createState() => _AutoCompleteSearchState();
}

class _AutoCompleteSearchState extends State<AutoCompleteSearch> {
  TextEditingController controller = TextEditingController();
  Timer debounceTimer;
  OverlayEntry overlayEntry;
  SearchProvider provider = SearchProvider();

  @override
  void initState() {
    super.initState();
    controller.addListener(_onSearchInputChange);
  }

  @override
  void dispose() {
    controller.removeListener(_onSearchInputChange);
    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(">>> Build [AutocompleteSearch] Component");
    return ChangeNotifierProvider.value(
      value: provider,
      child: RoundedFrame(
        height: widget.height,
        padding: const EdgeInsets.only(right: 10),
        color: Theme.of(context).brightness == Brightness.dark ? Colors.black54 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 8.0,
        child: Row(
          children: <Widget>[
            SizedBox(width: 10),
            Icon(Icons.search),
            SizedBox(width: 10),
            Expanded(child: _buildSearchTextField()),
            _buildTextClearIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTextField() {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: InputBorder.none,
        isDense: true,
        contentPadding: widget.contentPadding,
      ),
      onChanged: (value) {
        provider.searchTerm = value;
      },
    );
  }

  Widget _buildTextClearIcon() {
    return Selector<SearchProvider, String>(
        selector: (_, provider) => provider.searchTerm,
        builder: (_, data, __) {
          if (data.length > 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                child: Icon(
                  Icons.clear,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
                onTap: () {
                  provider.searchTerm = "";
                  controller.clear();
                },
              ),
            );
          } else {
            return SizedBox(width: 10);
          }
        });
  }

  _onSearchInputChange() {
    if (controller.text.isEmpty) {
      debounceTimer?.cancel();
      _searchPlace(controller.text);
      return;
    }

    if (controller.text.substring(controller.text.length - 1) == " ") {
      debounceTimer?.cancel();
      return;
    }

    if (debounceTimer?.isActive ?? false) {
      debounceTimer.cancel();
    }

    debounceTimer = Timer(Duration(milliseconds: widget.debounceMilliseconds), () {
      _searchPlace(controller.text);
    });
  }

  _searchPlace(String searchTerm) {
    if (context == null) return;

    _clearOverlay();

    if (searchTerm.length < 1) return;

    _displayOverlay(_buildSearchingOverlay());

    _performAutoCompleteSearch(searchTerm);
  }

  _clearOverlay() {
    if (overlayEntry != null) {
      overlayEntry.remove();
      overlayEntry = null;
    }
  }

  _displayOverlay(Widget overlayChild) {
    _clearOverlay();

    final RenderBox appBarRenderBox = widget.appBarKey.currentContext.findRenderObject();
    final screenWidth = MediaQuery.of(context).size.width;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: appBarRenderBox.size.height,
        left: screenWidth * 0.05,
        width: screenWidth * 0.9,
        child: Material(
          elevation: 4.0,
          child: overlayChild,
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  Widget _buildSearchingOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: <Widget>[
          SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 24),
          Expanded(
            child: Text(
              'Searching...',
              style: TextStyle(fontSize: 16),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPredictionOverlay(List<Prediction> predictions) {
    return ListBody(
      children: predictions
          .map(
            (p) => PredictionTile(
              prediction: p,
              onTap: (selectedPrediction) {
                provider.searchTerm = "";
                controller.clear();
                FocusScope.of(context).unfocus();
                widget.onPicked(selectedPrediction);
              },
            ),
          )
          .toList(),
    );
  }

  _performAutoCompleteSearch(String searchTerm) async {
    PlaceProvider provider = PlaceProvider.of(context, listen: false);

    if (searchTerm.isNotEmpty) {
      final PlacesAutocompleteResponse response = await provider.places.autocomplete(
        searchTerm,
        sessionToken: widget.sessionToken,
        location: provider.currentPosition == null ? null : Location(provider.currentPosition.latitude, provider.currentPosition.longitude),
      );

      if (response.errorMessage?.isNotEmpty == true || response.status == "REQUEST_DENIED") {
        print("AutoCompleteSearch Error: " + response.errorMessage);
        if (widget.onSearchFailed != null) {
          widget.onSearchFailed(response.status);
        }
        return;
      }

      _displayOverlay(_buildPredictionOverlay(response.predictions));
    }
  }
}