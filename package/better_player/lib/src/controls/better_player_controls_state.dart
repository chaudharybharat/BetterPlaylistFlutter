// Dart imports:
import 'dart:math';

// Project imports:
import 'package:better_player/better_player.dart';
import 'package:better_player/src/controls/better_player_clickable_widget.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/hls/better_player_hls_audio_track.dart';
import 'package:better_player/src/hls/better_player_hls_track.dart';
import 'package:better_player/src/video_player/video_player.dart';

// Flutter imports:
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';

///Base class for both material and cupertino controls
abstract class BetterPlayerControlsState<T extends StatefulWidget>
    extends State<T> {
  ///Min. time of buffered video to hide loading timer (in milliseconds)
  static const int _bufferingInterval = 20000;

  BetterPlayerController? get betterPlayerController;

  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration;

  VideoPlayerValue? get latestValue;

  void cancelAndRestartTimer();

  bool isVideoFinished(VideoPlayerValue? videoPlayerValue) {
    return videoPlayerValue?.position != null &&
        videoPlayerValue?.duration != null &&
        videoPlayerValue!.position.inMilliseconds != 0 &&
        videoPlayerValue.duration!.inMilliseconds != 0 &&
        videoPlayerValue.position >= videoPlayerValue.duration!;
  }

  void skipBack() {
    cancelAndRestartTimer();
    final beginning = const Duration().inMilliseconds;
    final skip = (latestValue!.position -
            Duration(
                milliseconds: betterPlayerControlsConfiguration
                    .backwardSkipTimeInMilliseconds))
        .inMilliseconds;
    betterPlayerController!
        .seekTo(Duration(milliseconds: max(skip, beginning)));
  }

  void skipForward() {
    cancelAndRestartTimer();
    final end = latestValue!.duration!.inMilliseconds;
    final skip = (latestValue!.position +
            Duration(
                milliseconds: betterPlayerControlsConfiguration
                    .forwardSkipTimeInMilliseconds))
        .inMilliseconds;
    betterPlayerController!.seekTo(Duration(milliseconds: min(skip, end)));
  }

  void onShowMoreClicked() {
    _showModalBottomSheet([_buildMoreOptionsList()]);
  }

  Widget _buildMoreOptionsList() {
    final translations = betterPlayerController!.translations;
    return SingleChildScrollView(
      // ignore: avoid_unnecessary_containers
      child: Container(
        child: Column(
          children: [
            if (betterPlayerControlsConfiguration.enablePlaybackSpeed)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.playbackSpeedIcon,
                  translations.overflowMenuPlaybackSpeed, () {
                Navigator.of(context).pop();
                _showSpeedChooserWidget();
              }),
            if (betterPlayerControlsConfiguration.enableSubtitles)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.subtitlesIcon,
                  translations.overflowMenuSubtitles, () {
                Navigator.of(context).pop();
                _showSubtitlesSelectionWidget();
              }),
            if (betterPlayerControlsConfiguration.enableQualities)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.qualitiesIcon,
                  translations.overflowMenuQuality, () {
                Navigator.of(context).pop();
                _showQualitiesSelectionWidget();
              }),
            if (betterPlayerControlsConfiguration.enableAudioTracks)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.audioTracksIcon,
                  translations.overflowMenuAudioTracks, () {
                Navigator.of(context).pop();
                _showAudioTracksSelectionWidget();
              }),
            if (betterPlayerControlsConfiguration
                .overflowMenuCustomItems.isNotEmpty)
              ...betterPlayerControlsConfiguration.overflowMenuCustomItems.map(
                (customItem) => _buildMoreOptionsListRow(
                  customItem.icon,
                  customItem.title,
                  () {
                    Navigator.of(context).pop();
                    customItem.onClicked.call();
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptionsListRow(
      IconData icon, String name, void Function() onTap) {
    return BetterPlayerMaterialClickableWidget(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: betterPlayerControlsConfiguration.overflowMenuIconsColor,
            ),
            const SizedBox(width: 16),
            Text(
              name,
              style: _getOverflowMenuElementTextStyle(false),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedChooserWidget() {
    _showModalBottomSheet([
      _buildSpeedRow(0.25),
      _buildSpeedRow(0.5),
      _buildSpeedRow(0.75),
      _buildSpeedRow(1.0),
      _buildSpeedRow(1.25),
      _buildSpeedRow(1.5),
      _buildSpeedRow(1.75),
      _buildSpeedRow(2.0),
    ]);
  }

  Widget _buildSpeedRow(double value) {
    final bool isSelected =
        betterPlayerController!.videoPlayerController!.value.speed == value;

    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setSpeed(value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              "$value x",
              style: _getOverflowMenuElementTextStyle(isSelected),
            )
          ],
        ),
      ),
    );
  }

  ///Latest value can be null
  bool isLoading(VideoPlayerValue? latestValue) {
    if (latestValue != null) {
      if (!latestValue.isPlaying && latestValue.duration == null) {
        return true;
      }

      final Duration position = latestValue.position;

      Duration? bufferedEndPosition;
      if (latestValue.buffered.isNotEmpty == true) {
        bufferedEndPosition = latestValue.buffered.last.end;
      }

      if (bufferedEndPosition != null) {
        final difference = bufferedEndPosition - position;

        if (latestValue.isPlaying &&
            latestValue.isBuffering &&
            difference.inMilliseconds < _bufferingInterval) {
          return true;
        }
      }
    }
    return false;
  }

  void _showSubtitlesSelectionWidget() {
    final subtitles =
        List.of(betterPlayerController!.betterPlayerSubtitlesSourceList);
    final noneSubtitlesElementExists = subtitles.firstWhereOrNull(
            (source) => source.type == BetterPlayerSubtitlesSourceType.none) !=
        null;
    if (!noneSubtitlesElementExists) {
      subtitles.add(BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.none));
    }

    _showModalBottomSheet(
        subtitles.map((source) => _buildSubtitlesSourceRow(source)).toList());
  }

  Widget _buildSubtitlesSourceRow(BetterPlayerSubtitlesSource subtitlesSource) {
    final selectedSourceType =
        betterPlayerController!.betterPlayerSubtitlesSource;
    final bool isSelected = (subtitlesSource == selectedSourceType) ||
        (subtitlesSource.type == BetterPlayerSubtitlesSourceType.none &&
            subtitlesSource.type == selectedSourceType!.type);

    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setupSubtitleSource(subtitlesSource);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              subtitlesSource.type == BetterPlayerSubtitlesSourceType.none
                  ? betterPlayerController!.translations.generalNone
                  : subtitlesSource.name ??
                      betterPlayerController!.translations.generalDefault,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  ///Build both track and resolution selection
  ///Track selection is used for HLS videos
  ///Resolution selection is used for normal videos
  void _showQualitiesSelectionWidget() {
    final List<String> trackNames =
        betterPlayerController!.betterPlayerDataSource!.hlsTrackNames ?? [];
    final List<BetterPlayerHlsTrack> tracks =
        betterPlayerController!.betterPlayerTracks;
    final List<Widget> children = [];
    for (var index = 0; index < tracks.length; index++) {
      final track = tracks[index];

      String? preferredName;
      if (track.height == 0 && track.width == 0 && track.bitrate == 0) {
        preferredName = betterPlayerController!.translations.qualityAuto;
      } else {
        preferredName = trackNames.length > index ? trackNames[index] : null;
      }
      children.add(_buildTrackRow(tracks[index], preferredName));
    }

    final resolutions =
        betterPlayerController!.betterPlayerDataSource!.resolutions;
    resolutions?.forEach((key, value) {
      children.add(_buildResolutionSelectionRow(key, value));
    });

    if (children.isEmpty) {
      children.add(
        _buildTrackRow(BetterPlayerHlsTrack.defaultTrack(),
            betterPlayerController!.translations.qualityAuto),
      );
    }

    _showModalBottomSheet(children);
  }

  Widget _buildTrackRow(BetterPlayerHlsTrack track, String? preferredName) {
    final String trackName = preferredName ??
        "${track.width}x${track.height} ${BetterPlayerUtils.formatBitrate(track.bitrate!)}";

    final selectedTrack = betterPlayerController!.betterPlayerTrack;
    final bool isSelected = selectedTrack != null && selectedTrack == track;

    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setTrack(track);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              trackName,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionSelectionRow(String name, String url) {
    final bool isSelected =
        url == betterPlayerController!.betterPlayerDataSource!.url;
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setResolution(url);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              name,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioTracksSelectionWidget() {
    final List<BetterPlayerHlsAudioTrack>? tracks =
        betterPlayerController!.betterPlayerAudioTracks;
    final List<Widget> children = [];
    final BetterPlayerHlsAudioTrack? selectedAudioTrack =
        betterPlayerController!.betterPlayerAudioTrack;
    if (tracks != null) {
      for (var index = 0; index < tracks.length; index++) {
        final bool isSelected =
            selectedAudioTrack != null && selectedAudioTrack == tracks[index];
        children.add(_buildAudioTrackRow(tracks[index], isSelected));
      }
    }

    if (children.isEmpty) {
      children.add(
        _buildAudioTrackRow(
          BetterPlayerHlsAudioTrack(
            label: betterPlayerController!.translations.generalDefault,
          ),
          true,
        ),
      );
    }

    _showModalBottomSheet(children);
  }

  Widget _buildAudioTrackRow(
      BetterPlayerHlsAudioTrack audioTrack, bool isSelected) {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setAudioTrack(audioTrack);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              audioTrack.label!,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _getOverflowMenuElementTextStyle(bool isSelected) {
    return TextStyle(
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: betterPlayerControlsConfiguration.overflowModalTextColor,
    );
  }

  void _showModalBottomSheet(List<Widget> children) {
    showModalBottomSheet<void>(
      backgroundColor: betterPlayerControlsConfiguration.overflowModalColor,
      context: context,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              children: children,
            ),
          ),
        );
      },
    );
  }
}
