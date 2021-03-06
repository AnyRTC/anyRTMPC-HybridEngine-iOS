//
//  ArVideoHostController.m
//  RTMPCDemo
//
//  Created by 余生丶 on 2019/4/10.
//  Copyright © 2019 anyRTC. All rights reserved.
//

#import "ArVideoHostController.h"
#import "ArRealTimeMicController.h"

@interface ArVideoHostController ()<ARHosterRtmpDelegate,ARHosterRtcDelegate,HangUpDelegate>

@property (weak, nonatomic) IBOutlet UIButton *micButton;

@property (nonatomic, strong) ARRtmpHosterKit *hosterKit;
/** 连麦请求 */
@property(nonatomic ,strong) NSMutableArray *micArr;

@end

@implementation ArVideoHostController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    NSMutableString *roomText = [[NSMutableString alloc] initWithString:self.liveInfo.anyrtcId];
    [roomText insertString:@" " atIndex:4];
    self.roomIdLabel.text = [NSString stringWithFormat:@"房间名称：%@",roomText];
    self.micArr = [NSMutableArray arrayWithCapacity:3];
    [self setUpInitialization];
}

- (void)setUpInitialization {
    ARHosterOption *option = [ARHosterOption defaultOption];
    option.livingMediaMode = ARLivingMediaModeVideo;
    option.cameraType = ARRtmpCameraTypeBeauty;
    //实例化主播对象
    self.hosterKit = [[ARRtmpHosterKit alloc] initWithDelegate:self option:option];
    self.hosterKit.rtc_delegate = self;
    [self.hosterKit setLocalVideoCapturer:self.view];
    [self.hosterKit startPushRtmpStream:self.liveInfo.push_url];
    
    //用户信息
    ArUserInfo *userInfo = ArUserManager.getUserInfo;
    NSDictionary *userData = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1],@"isHost",userInfo.userid,@"userId",userInfo.nickname,@"nickName",userInfo.avatar,@"headUrl", nil];
    //直播信息
    NSDictionary *liveData = [NSDictionary dictionaryWithObjectsAndKeys:self.liveInfo.pull_url,@"rtmpUrl",self.liveInfo.hls_url,@"hlsUrl",self.liveInfo.anyrtcId,@"anyrtcId",self.liveInfo.anyrtcId,@"liveTopic",[NSNumber numberWithInt:0],@"isLiveLandscape",[NSNumber numberWithInt:0],@"isAudioLive",userInfo.nickname,@"hosterName",nil];
    
    if (![self.hosterKit createRTCLineByToken:nil liveId:self.liveInfo.anyrtcId userId:userInfo.userid userData:[ArCommon fromDicToJSONStr:userData] liveInfo:[ArCommon fromDicToJSONStr:liveData]]) {
        [ArCommon showAlertsStatus:@"创建RTC失败"];
    }
    
    ArMethodText(@"initWithDelegate:");
    ArMethodText(@"setLocalVideoCapturer:");
    ArMethodText(@"startPushRtmpStream:");
    ArMethodText(@"createRTCLineByToken:");
}

- (IBAction)handleSomethingEvent:(UIButton *)sender {
    sender.selected = !sender.selected;
    switch (sender.tag) {
        case 50:
            //消息
            [self.messageTextField becomeFirstResponder];
            break;
        case 51:
            //连麦列表
        {
            sender.selected = NO;
            ArRealTimeMicController *micVc = [[self storyboard] instantiateViewControllerWithIdentifier:@"RTMPC_RealTimeMic"];
            micVc.hosterKit = self.hosterKit;
            micVc.micArr = self.micArr;
            micVc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
            [self presentViewController:micVc animated:YES completion:nil];
        }
            break;
        case 52:
            //美颜
            [self.hosterKit setCameraFilter:sender.selected];
            ArMethodText(@"setCameraFilter:");
            break;
        case 53:
            //退出
        {
            WEAKSELF;
            [UIAlertController showAlertInViewController:self withTitle:@"确认关闭直播？" message:nil cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@[@"退出"] tapBlock:^(UIAlertController * _Nonnull controller, UIAlertAction * _Nonnull action, NSInteger buttonIndex) {
                if (buttonIndex == 2) {
                    [weakSelf.hosterKit clear];
                    ArMethodText(@"clear");
                    [weakSelf dismissViewControllerAnimated:YES completion:nil];
                }
            }];
        }
            break;
        case 54:
            //旋转摄像头
            [self.hosterKit switchCamera];
            ArMethodText(@"switchCamera");
            break;
        case 55:
            //日志
            [self openLogView];
            break;
        default:
            break;
    }
}

//MARK: - HangUpDelegate

- (void)hangUpOperation:(NSString *)peerId {
    [self.hosterKit hangupRTCLine:peerId];
    [self.videoStackView.subviews enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[ArVideoView class]]) {
            ArVideoView *video = (ArVideoView *)obj;
            if ([video.peerId isEqualToString:peerId]) {
                [video removeFromSuperview];
                *stop = YES;
            }
        }
    }];
    ArMethodText(@"hangupRTCLine:");
}

//MARK: - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    if (textField.text != nil) {
        ArUserInfo *userInfo = ArUserManager.getUserInfo;
        [self.messageView addMessage:[self produceTextInfo:userInfo.nickname content:textField.text userId:userInfo.userid audio:NO]];
        //发送消息
        [self.hosterKit sendUserMessage:ARNomalMessageType userName:ArUserManager.getUserInfo.nickname userHeader:@"" content:textField.text];
        textField.text = @"";
        [textField resignFirstResponder];
        ArMethodText(@"sendUserMessage:");
    }
    return YES;
}

//MARK: - ARHosterRtmpDelegate

- (void)onRtmpStreamOk {
    //RTMP 服务连接成功
    self.rtmpLabel.text = @"RTMP服务链接成功";
    ArCallbackLog;
}

- (void)onRtmpStreamReconnecting:(int)times {
    //RTMP 服务重连
    self.rtmpLabel.text = [NSString stringWithFormat:@"RTMP服务第%d次重连中...",times];
    ArCallbackLog;
}

- (void)onRtmpStreamStatus:(int)delayTime netBand:(int)netBand {
    //RTMP 推流状态
    self.rtmpLabel.text = [NSString stringWithFormat:@"RTMP延迟:%.2fs 当前上传网速:%.2fkb/s",delayTime/1000.00,netBand/1024.00/8];
    ArCallbackLog;
}

- (void)onRtmpStreamFailed:(ARRtmpCode)code {
    //RTMP 服务连接失败
    self.rtmpLabel.text = @"RTMP服务连接失败";
    ArCallbackLog;
}

- (void)onRtmpStreamClosed {
    //RTMP 服务关闭
    self.rtmpLabel.text = @"RTMP服务关闭";
    ArCallbackLog;
}

//MARK: - ARHosterRtcDelegate

- (void)onRTCCreateLineResult:(ARRtmpCode)code reason:(NSString *)reason {
    //创建RTC服务连接结果
    (code == ARRtmp_OK) ? (self.rtcLabel.text = @"RTC服务链接成功") : (self.rtcLabel.text = @"RTC服务链接出错");
    ArCallbackLog;
}

- (void)onRTCApplyToLine:(NSString *)peerId userId:(NSString *)userId userData:(NSString *)userData {
    //主播收到游客连麦请求
    self.micButton.selected = YES;
    [self.micArr addObject:[self produceRealModel:peerId userId:userId userData:userData]];
    [NSNotificationCenter.defaultCenter postNotificationName:@"LineNumChangeNotification" object:self.micArr];
    ArCallbackLog;
}

- (void)onRTCCancelLine:(ARRtmpCode)code peerId:(NSString *)peerId {
    //游客取消连麦申请，或者连麦已满
    if (code == ARRtmp_OK) {
        [self.micArr enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:[ArRealMicModel class]]) {
                ArRealMicModel *micModel = (ArRealMicModel *)obj;
                if ([micModel.peerId isEqualToString:peerId]) {
                    [self.micArr removeObjectAtIndex:idx];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"LineNumChangeNotification" object:self.micArr];
                    *stop = YES;
                }
            }
        }];
    }
    self.micButton.selected = self.micArr.count;
    ArCallbackLog;
}

- (void)onRTCLineClosed:(ARRtmpCode)code {
    //RTC 服务关闭
    ArCallbackLog;
}

- (void)onRTCOpenRemoteVideoRender:(NSString *)peerId pubId:(NSString *)pubId userId:(NSString *)userId userData:(NSString *)userData {
    //游客视频连麦接通
    ArVideoView *videoView = [[ArVideoView alloc] initWithPeerId:peerId pubId:pubId display:YES];
    videoView.delegate = self;
    [self.videoStackView addArrangedSubview:videoView];
    [videoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.videoStackView.mas_width);
        make.height.equalTo(videoView.mas_width).multipliedBy(1.333);
    }];
    [self.hosterKit setRemoteVideoRender:videoView pubId:pubId];
    ArCallbackLog;
    ArMethodText(@"setRemoteVideoRender:");
}

- (void)onRTCCloseRemoteVideoRender:(NSString *)peerId pubId:(NSString *)pubId userId:(NSString *)userId {
    //游客视频连麦挂断
    [self.videoStackView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        ArVideoView *videoView = (ArVideoView *)obj;
        if ([videoView.pubId isEqualToString:pubId]) {
            [videoView removeFromSuperview];
            *stop = YES;
        }
    }];
    ArCallbackLog;
}

- (void)onRTCRemoteAVStatus:(NSString *)peerId audio:(BOOL)audio video:(BOOL)video {
    //其他人对音视频的操作
    ArCallbackLog;
}

- (void)onRTCFirstLocalVideoFrame:(CGSize)size {
    //本地视频第一帧
    ArCallbackLog;
}

- (void)onRTCFirstRemoteVideoFrame:(CGSize)size pubId:(NSString *)pubId {
    //远程视频第一帧
    ArCallbackLog;
}

- (void)onRTCLocalVideoViewChanged:(CGSize)size {
    //本地窗口大小的回调
    ArCallbackLog;
}

- (void)onRTCRemoteVideoViewChanged:(CGSize)size pubId:(NSString *)pubId {
    //远程窗口大小的回调
    ArCallbackLog;
}

- (void)onRTCLocalAudioActive:(int)level showTime:(int)time {
    //本地音频检测回调
    ArCallbackLog;
}

- (void)onRTCRemoteAudioActive:(NSString *)peerId userId:(NSString *)userId audioLevel:(int)level showTime:(int)time {
    //其他与会者音频检测回调
    ArCallbackLog;
}

- (void)onRTCUserMessage:(ARMessageType)type userId:(NSString *)userId userName:(NSString *)userName userHeader:(NSString *)headerUrl content:(NSString *)content {
    //收到消息回调
    [self.messageView addMessage:[self produceTextInfo:userName content:content userId:userId audio:NO]];
    ArCallbackLog;
}

- (void)onRTCMemberListNotify:(NSString *)serverId roomId:(NSString *)roomId allMember:(int)totalMember {
    //直播间实时在线人数变化通知
    self.onlineLabel.text = [NSString stringWithFormat:@"在线人数：%d",totalMember];
    ArCallbackLog;
}

- (CVPixelBufferRef)cameraSourceDidGetPixelBuffer:(CMSampleBufferRef)sampleBuffer {
    //获取视频的原始采集数据
    ArCallbackLog;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    return pixelBuffer;
}

@end
