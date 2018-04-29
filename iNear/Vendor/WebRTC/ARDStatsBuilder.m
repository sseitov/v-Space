/*
 *  Copyright 2015 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import "ARDStatsBuilder.h"

#import "WebRTC/RTCLegacyStatsReport.h"

#import "ARDBitrateTracker.h"
#import "ARDUtilities.h"

@implementation ARDStatsBuilder {
  // Connection stats.
  NSString *_connRecvBitrate;
  NSString *_connRtt;
  NSString *_connSendBitrate;
  NSString *_localCandType;
  NSString *_remoteCandType;
  NSString *_transportType;

  // BWE stats.
  NSString *_actualEncBitrate;
  NSString *_availableRecvBw;
  NSString *_availableSendBw;
  NSString *_targetEncBitrate;

  // Video send stats.
  NSString *_videoEncodeMs;
  NSString *_videoInputFps;
  NSString *_videoInputHeight;
  NSString *_videoInputWidth;
  NSString *_videoSendCodec;
  NSString *_videoSendBitrate;
  NSString *_videoSendFps;
  NSString *_videoSendHeight;
  NSString *_videoSendWidth;

  // QP stats.
  int _videoQPSum;
  int _framesEncoded;
  int _oldVideoQPSum;
  int _oldFramesEncoded;

  // Video receive stats.
  NSString *_videoDecodeMs;
  NSString *_videoDecodedFps;
  NSString *_videoOutputFps;
  NSString *_videoRecvBitrate;
  NSString *_videoRecvFps;
  NSString *_videoRecvHeight;
  NSString *_videoRecvWidth;

  // Audio send stats.
  NSString *_audioSendBitrate;
  NSString *_audioSendCodec;

  // Audio receive stats.
  NSString *_audioCurrentDelay;
  NSString *_audioExpandRate;
  NSString *_audioRecvBitrate;
  NSString *_audioRecvCodec;

  // Bitrate trackers.
  ARDBitrateTracker *_audioRecvBitrateTracker;
  ARDBitrateTracker *_audioSendBitrateTracker;
  ARDBitrateTracker *_connRecvBitrateTracker;
  ARDBitrateTracker *_connSendBitrateTracker;
  ARDBitrateTracker *_videoRecvBitrateTracker;
  ARDBitrateTracker *_videoSendBitrateTracker;
}

- (instancetype)init {
  if (self = [super init]) {
    _audioSendBitrateTracker = [[ARDBitrateTracker alloc] init];
    _audioRecvBitrateTracker = [[ARDBitrateTracker alloc] init];
    _connSendBitrateTracker = [[ARDBitrateTracker alloc] init];
    _connRecvBitrateTracker = [[ARDBitrateTracker alloc] init];
    _videoSendBitrateTracker = [[ARDBitrateTracker alloc] init];
    _videoRecvBitrateTracker = [[ARDBitrateTracker alloc] init];
    _videoQPSum = 0;
    _framesEncoded = 0;
  }
  return self;
}

- (NSString *)statsString {
  NSMutableString *result = [NSMutableString string];
  NSString *systemStatsFormat = @"(cpu)%ld%%\n";
  [result appendString:[NSString stringWithFormat:systemStatsFormat,
      (long)ARDGetCpuUsagePercentage()]];

  // Connection stats.
  NSString *connStatsFormat = @"CN %@ms | %@->%@/%@ | (s)%@ | (r)%@\n";
  [result appendString:[NSString stringWithFormat:connStatsFormat,
      _connRtt,
      _localCandType, _remoteCandType, _transportType,
      _connSendBitrate, _connRecvBitrate]];

  // Video send stats.
  NSString *videoSendFormat = @"VS (input) %@x%@@%@fps | (sent) %@x%@@%@fps\n"
                               "VS (enc) %@/%@ | (sent) %@/%@ | %@ms | %@\n"
                               "AvgQP (past %d encoded frames) = %d\n ";
  int avgqp = [self calculateAvgQP];

  [result appendString:[NSString stringWithFormat:videoSendFormat,
      _videoInputWidth, _videoInputHeight, _videoInputFps,
      _videoSendWidth, _videoSendHeight, _videoSendFps,
      _actualEncBitrate, _targetEncBitrate,
      _videoSendBitrate, _availableSendBw,
      _videoEncodeMs,
      _videoSendCodec,
      _framesEncoded - _oldFramesEncoded, avgqp]];

  // Video receive stats.
  NSString *videoReceiveFormat =
      @"VR (recv) %@x%@@%@fps | (decoded)%@ | (output)%@fps | %@/%@ | %@ms\n";
  [result appendString:[NSString stringWithFormat:videoReceiveFormat,
      _videoRecvWidth, _videoRecvHeight, _videoRecvFps,
      _videoDecodedFps,
      _videoOutputFps,
      _videoRecvBitrate, _availableRecvBw,
      _videoDecodeMs]];

  // Audio send stats.
  NSString *audioSendFormat = @"AS %@ | %@\n";
  [result appendString:[NSString stringWithFormat:audioSendFormat,
      _audioSendBitrate, _audioSendCodec]];

  // Audio receive stats.
  NSString *audioReceiveFormat = @"AR %@ | %@ | %@ms | (expandrate)%@";
  [result appendString:[NSString stringWithFormat:audioReceiveFormat,
      _audioRecvBitrate, _audioRecvCodec, _audioCurrentDelay,
      _audioExpandRate]];

  return result;
}

- (void)parseStatsReport:(RTCLegacyStatsReport *)statsReport {
  NSString *reportType = statsReport.type;
  if ([reportType isEqualToString:@"ssrc"] &&
      [statsReport.reportId rangeOfString:@"ssrc"].location != NSNotFound) {
    if ([statsReport.reportId rangeOfString:@"send"].location != NSNotFound) {
      [self parseSendSsrcStatsReport:statsReport];
    }
    if ([statsReport.reportId rangeOfString:@"recv"].location != NSNotFound) {
      [self parseRecvSsrcStatsReport:statsReport];
    }
  } else if ([reportType isEqualToString:@"VideoBwe"]) {
    [self parseBweStatsReport:statsReport];
  } else if ([reportType isEqualToString:@"googCandidatePair"]) {
    [self parseConnectionStatsReport:statsReport];
  }
}

#pragma mark - Private

- (int)calculateAvgQP {
  int deltaFramesEncoded = _framesEncoded - _oldFramesEncoded;
  int deltaQPSum = _videoQPSum - _oldVideoQPSum;

  return deltaFramesEncoded != 0 ? deltaQPSum / deltaFramesEncoded : 0;
}

- (void)parseBweStatsReport:(RTCLegacyStatsReport *)statsReport {
  [statsReport.values enumerateKeysAndObjectsUsingBlock:^(
      NSString *key, NSString *value, BOOL *stop) {
    if ([key isEqualToString:@"googAvailableSendBandwidth"]) {
        self->_availableSendBw =
          [ARDBitrateTracker bitrateStringForBitrate:value.doubleValue];
    } else if ([key isEqualToString:@"googAvailableReceiveBandwidth"]) {
        self->_availableRecvBw =
          [ARDBitrateTracker bitrateStringForBitrate:value.doubleValue];
    } else if ([key isEqualToString:@"googActualEncBitrate"]) {
        self->_actualEncBitrate =
          [ARDBitrateTracker bitrateStringForBitrate:value.doubleValue];
    } else if ([key isEqualToString:@"googTargetEncBitrate"]) {
        self->_targetEncBitrate =
          [ARDBitrateTracker bitrateStringForBitrate:value.doubleValue];
    }
  }];
}

- (void)parseConnectionStatsReport:(RTCLegacyStatsReport *)statsReport {
  NSString *activeConnection = statsReport.values[@"googActiveConnection"];
  if (![activeConnection isEqualToString:@"true"]) {
    return;
  }
  [statsReport.values enumerateKeysAndObjectsUsingBlock:^(
      NSString *key, NSString *value, BOOL *stop) {
    if ([key isEqualToString:@"googRtt"]) {
        self->_connRtt = value;
    } else if ([key isEqualToString:@"googLocalCandidateType"]) {
        self->_localCandType = value;
    } else if ([key isEqualToString:@"googRemoteCandidateType"]) {
        self->_remoteCandType = value;
    } else if ([key isEqualToString:@"googTransportType"]) {
        self->_transportType = value;
    } else if ([key isEqualToString:@"bytesReceived"]) {
      NSInteger byteCount = value.integerValue;
        [self->_connRecvBitrateTracker updateBitrateWithCurrentByteCount:byteCount];
        self->_connRecvBitrate = self->_connRecvBitrateTracker.bitrateString;
    } else if ([key isEqualToString:@"bytesSent"]) {
      NSInteger byteCount = value.integerValue;
        [self->_connSendBitrateTracker updateBitrateWithCurrentByteCount:byteCount];
        self->_connSendBitrate = self->_connSendBitrateTracker.bitrateString;
    }
  }];
}

- (void)parseSendSsrcStatsReport:(RTCLegacyStatsReport *)statsReport {
  NSDictionary *values = statsReport.values;
  if ([values objectForKey:@"googFrameRateSent"]) {
    // Video track.
    [self parseVideoSendStatsReport:statsReport];
  } else if ([values objectForKey:@"audioInputLevel"]) {
    // Audio track.
    [self parseAudioSendStatsReport:statsReport];
  }
}

- (void)parseAudioSendStatsReport:(RTCLegacyStatsReport *)statsReport {
  [statsReport.values enumerateKeysAndObjectsUsingBlock:^(
      NSString *key, NSString *value, BOOL *stop) {
    if ([key isEqualToString:@"googCodecName"]) {
        self->_audioSendCodec = value;
    } else if ([key isEqualToString:@"bytesSent"]) {
      NSInteger byteCount = value.integerValue;
        [self->_audioSendBitrateTracker updateBitrateWithCurrentByteCount:byteCount];
        self->_audioSendBitrate = self->_audioSendBitrateTracker.bitrateString;
    }
  }];
}

- (void)parseVideoSendStatsReport:(RTCLegacyStatsReport *)statsReport {
  [statsReport.values enumerateKeysAndObjectsUsingBlock:^(
      NSString *key, NSString *value, BOOL *stop) {
    if ([key isEqualToString:@"googCodecName"]) {
        self->_videoSendCodec = value;
    } else if ([key isEqualToString:@"googFrameHeightInput"]) {
        self->_videoInputHeight = value;
    } else if ([key isEqualToString:@"googFrameWidthInput"]) {
        self->_videoInputWidth = value;
    } else if ([key isEqualToString:@"googFrameRateInput"]) {
        self->_videoInputFps = value;
    } else if ([key isEqualToString:@"googFrameHeightSent"]) {
        self->_videoSendHeight = value;
    } else if ([key isEqualToString:@"googFrameWidthSent"]) {
        self->_videoSendWidth = value;
    } else if ([key isEqualToString:@"googFrameRateSent"]) {
        self->_videoSendFps = value;
    } else if ([key isEqualToString:@"googAvgEncodeMs"]) {
        self->_videoEncodeMs = value;
    } else if ([key isEqualToString:@"bytesSent"]) {
      NSInteger byteCount = value.integerValue;
        [self->_videoSendBitrateTracker updateBitrateWithCurrentByteCount:byteCount];
        self->_videoSendBitrate = self->_videoSendBitrateTracker.bitrateString;
    } else if ([key isEqualToString:@"qpSum"]) {
        self->_oldVideoQPSum = self->_videoQPSum;
        self->_videoQPSum = value.intValue;
    } else if ([key isEqualToString:@"framesEncoded"]) {
        self->_oldFramesEncoded = self->_framesEncoded;
        self->_framesEncoded = value.intValue;
    }
  }];
}

- (void)parseRecvSsrcStatsReport:(RTCLegacyStatsReport *)statsReport {
  NSDictionary *values = statsReport.values;
  if ([values objectForKey:@"googFrameWidthReceived"]) {
    // Video track.
    [self parseVideoRecvStatsReport:statsReport];
  } else if ([values objectForKey:@"audioOutputLevel"]) {
    // Audio track.
    [self parseAudioRecvStatsReport:statsReport];
  }
}

- (void)parseAudioRecvStatsReport:(RTCLegacyStatsReport *)statsReport {
  [statsReport.values enumerateKeysAndObjectsUsingBlock:^(
      NSString *key, NSString *value, BOOL *stop) {
    if ([key isEqualToString:@"googCodecName"]) {
        self->_audioRecvCodec = value;
    } else if ([key isEqualToString:@"bytesReceived"]) {
      NSInteger byteCount = value.integerValue;
        [self->_audioRecvBitrateTracker updateBitrateWithCurrentByteCount:byteCount];
        self->_audioRecvBitrate = self->_audioRecvBitrateTracker.bitrateString;
    } else if ([key isEqualToString:@"googSpeechExpandRate"]) {
        self->_audioExpandRate = value;
    } else if ([key isEqualToString:@"googCurrentDelayMs"]) {
        self->_audioCurrentDelay = value;
    }
  }];
}

- (void)parseVideoRecvStatsReport:(RTCLegacyStatsReport *)statsReport {
  [statsReport.values enumerateKeysAndObjectsUsingBlock:^(
      NSString *key, NSString *value, BOOL *stop) {
    if ([key isEqualToString:@"googFrameHeightReceived"]) {
        self->_videoRecvHeight = value;
    } else if ([key isEqualToString:@"googFrameWidthReceived"]) {
        self->_videoRecvWidth = value;
    } else if ([key isEqualToString:@"googFrameRateReceived"]) {
        self->_videoRecvFps = value;
    } else if ([key isEqualToString:@"googFrameRateDecoded"]) {
        self->_videoDecodedFps = value;
    } else if ([key isEqualToString:@"googFrameRateOutput"]) {
        self->_videoOutputFps = value;
    } else if ([key isEqualToString:@"googDecodeMs"]) {
        self->_videoDecodeMs = value;
    } else if ([key isEqualToString:@"bytesReceived"]) {
      NSInteger byteCount = value.integerValue;
        [self->_videoRecvBitrateTracker updateBitrateWithCurrentByteCount:byteCount];
        self->_videoRecvBitrate = self->_videoRecvBitrateTracker.bitrateString;
    }
  }];
}

@end

