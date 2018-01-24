//
//  FaceStreamDetectorViewController.m
//  IFlyFaceDemo
//
//  Created by 张剑 on 15/6/25.
//  Copyright (c) 2015年 iflytek. All rights reserved.
//

#import "FaceStreamDetectorViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/QuartzCore.h>
#import "PermissionDetector.h"
#import "UIImage+Extensions.h"
#import "UIImage+compress.h"
#import "iflyMSC/IFlyFaceSDK.h"
#import "DemoPreDefine.h"
#import "CaptureManager.h"
#import "CanvasView.h"
#import "CalculatorTools.h"
#import "UIImage+Extensions.h"
#import "IFlyFaceImage.h"
#import "IFlyFaceResultKeys.h"

// 人脸验证相关
#import "UIImage+Extensions.h"
#import "UIImage+compress.h"
#import <CoreGraphics/CoreGraphics.h>


@interface FaceStreamDetectorViewController ()<CaptureManagerDelegate,IFlyFaceRequestDelegate>

@property (nonatomic, retain ) IBOutlet    UIView         *previewView;
@property (nonatomic, strong ) IBOutlet    UISwitch       *detectSwitch;
@property (nonatomic, strong ) IBOutlet    UISwitch       *alignSwitch;

@property (nonatomic, retain ) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, retain ) CaptureManager             *captureManager;

@property (nonatomic, retain ) IFlyFaceDetector           *faceDetector;
@property (nonatomic, strong ) CanvasView                 *viewCanvas;
@property (nonatomic, strong ) UITapGestureRecognizer     *tapGesture;



@property (nonatomic, assign ) BOOL isLockTap;

// 人脸验证相关
@property (nonatomic, strong ) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong ) IFlyFaceRequest * iFlySpFaceRequest;
@property (nonatomic, copy   ) NSString *resultStings;
@property (nonatomic, copy   ) IFlyFaceImage * faceImage;
@property (nonatomic, assign)  BOOL isVerified;

-(IBAction)onDetectSwitchClicked:(UISwitch*)sender;
-(IBAction)onAlignSwitchClicked:(UISwitch*)sender;

@end

@implementation FaceStreamDetectorViewController
@synthesize captureManager;


#pragma mark - View lifecycle

-(void)dealloc{
    self.captureManager=nil;
    self.viewCanvas=nil;
    [self.previewView removeGestureRecognizer:self.tapGesture];
    self.tapGesture=nil;
    
}


- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    self.title = @"离线视频检测示例";
    
    //adjust the UI for iOS 7
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if ( IOS7_OR_LATER ){
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.extendedLayoutIncludesOpaqueBars = NO;
        self.modalPresentationCapturesStatusBarAppearance = NO;
        self.navigationController.navigationBar.translucent = NO;
    }
#endif
    
    self.view.backgroundColor=[UIColor blackColor];
    self.previewView.backgroundColor=[UIColor blackColor];
    
    // 初始化人脸验证相关
    self.iFlySpFaceRequest=[IFlyFaceRequest sharedInstance];
    [self.iFlySpFaceRequest setDelegate:self];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    CGRect rect= self.activityIndicator.frame;
    self.activityIndicator.frame=CGRectMake(rect.origin.x-1.5*rect.size.width, rect.origin.y-1.5*rect.size.height, 3*rect.size.width, 3*rect.size.height);
    [self.activityIndicator setHidden:YES];
    [self.view addSubview:self.activityIndicator];
    
    // 初始化人脸检测
    self.faceDetector=[IFlyFaceDetector sharedInstance];
    
    //初始化 CaptureSessionManager
    self.captureManager=[[CaptureManager alloc] init];
    self.captureManager.delegate=self;
    
    self.previewLayer=self.captureManager.previewLayer;
    
    self.captureManager.previewLayer.frame= self.previewView.frame;
    self.captureManager.previewLayer.position=self.previewView.center;
    self.captureManager.previewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
    [self.previewView.layer addSublayer:self.captureManager.previewLayer];

    
    self.viewCanvas = [[CanvasView alloc] initWithFrame:self.captureManager.previewLayer.frame] ;
    [self.previewView addSubview:self.viewCanvas] ;
    self.viewCanvas.center=self.captureManager.previewLayer.position;
    self.viewCanvas.backgroundColor = [UIColor clearColor] ;
    
    self.tapGesture=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onViewClicked:)];
    [self.previewView addGestureRecognizer:self.tapGesture];
    
    //建立 AVCaptureStillImageOutput
//    self.myStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
//    NSDictionary *myOutputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
//    [self.myStillImageOutput setOutputSettings:myOutputSettings];
//    [self.captureManager.session addOutput:self.myStillImageOutput];
    
    [self.captureManager setup];
    [self.captureManager addObserver];
    
    if(self.faceDetector){
        BOOL isDetect=[[self.faceDetector parameterForKey:@"detect"] boolValue];
        BOOL isAlign=[[self.faceDetector parameterForKey:@"align"] boolValue];
        
        [self.detectSwitch setOn:isDetect];
        [self.alignSwitch setOn:isAlign];
    }
    
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    
    [self.captureManager removeObserver];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    [self.captureManager observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - Actions

- (void)onViewClicked:(id)sender {
    if(!self.isLockTap){
        [self.captureManager cameraToggle];
    }
}

-(IBAction)onDetectSwitchClicked:(UISwitch*)sender{
    NSString* strEnable=[NSString stringWithFormat:@"%@",[sender isOn]?@"1":@"0"] ;
    [self.faceDetector setParameter:strEnable forKey:@"detect"];
    
}

-(IBAction)onAlignSwitchClicked:(UISwitch*)sender{
    NSString* strEnable=[NSString stringWithFormat:@"%@",[sender isOn]?@"1":@"0"] ;
    [self.faceDetector setParameter:strEnable forKey:@"align"];
}

#pragma mark - Data Parser

- (void) showFaceLandmarksAndFaceRectWithPersonsArray:(NSMutableArray *)arrPersons{
    if (self.viewCanvas.hidden) {
        self.viewCanvas.hidden = NO ;
    }
    self.viewCanvas.arrPersons = arrPersons ;
    [self.viewCanvas setNeedsDisplay] ;
}

- (void) hideFace {
    if (!self.viewCanvas.hidden) {
        self.viewCanvas.hidden = YES ;
    }
}

-(NSString*)praseDetect:(NSDictionary* )positionDic OrignImage:(IFlyFaceImage*)faceImg{
    
    if(!positionDic){
        return nil;
    }
    

    
    // 判断摄像头方向
    BOOL isFrontCamera=self.captureManager.videoDeviceInput.device.position==AVCaptureDevicePositionFront;
    
    // scale coordinates so they fit in the preview box, which may be scaled
    CGFloat widthScaleBy = self.previewLayer.frame.size.width / faceImg.height;
    CGFloat heightScaleBy = self.previewLayer.frame.size.height / faceImg.width;
    
    CGFloat bottom =[[positionDic objectForKey:KCIFlyFaceResultBottom] floatValue];
    CGFloat top=[[positionDic objectForKey:KCIFlyFaceResultTop] floatValue];
    CGFloat left=[[positionDic objectForKey:KCIFlyFaceResultLeft] floatValue];
    CGFloat right=[[positionDic objectForKey:KCIFlyFaceResultRight] floatValue];

    
    float cx = (left+right)/2;
    float cy = (top + bottom)/2;
    float w = right - left;
    float h = bottom - top;
    
    float ncx = cy ;
    float ncy = cx ;
    
    CGRect rectFace = CGRectMake(ncx-w/2 ,ncy-w/2 , w, h);
    
    if(!isFrontCamera){
        rectFace=rSwap(rectFace);
        rectFace=rRotate90(rectFace, faceImg.height, faceImg.width);
    }
    
    rectFace=rScale(rectFace, widthScaleBy, heightScaleBy);
    
    return NSStringFromCGRect(rectFace);

}

-(NSMutableArray*)praseAlign:(NSDictionary* )landmarkDic OrignImage:(IFlyFaceImage*)faceImg{
    if(!landmarkDic){
        return nil;
    }
    
    // 判断摄像头方向
    BOOL isFrontCamera=self.captureManager.videoDeviceInput.device.position==AVCaptureDevicePositionFront;
    
    // scale coordinates so they fit in the preview box, which may be scaled
    CGFloat widthScaleBy = self.previewLayer.frame.size.width / faceImg.height;
    CGFloat heightScaleBy = self.previewLayer.frame.size.height / faceImg.width;
    
    NSMutableArray *arrStrPoints = [NSMutableArray array] ;
    NSEnumerator* keys=[landmarkDic keyEnumerator];
    for(id key in keys){
        id attr=[landmarkDic objectForKey:key];
        if(attr && [attr isKindOfClass:[NSDictionary class]]){
            
            id attr=[landmarkDic objectForKey:key];
            CGFloat x=[[attr objectForKey:KCIFlyFaceResultPointX] floatValue];
            CGFloat y=[[attr objectForKey:KCIFlyFaceResultPointY] floatValue];
            
            CGPoint p = CGPointMake(y,x);
            
            if(!isFrontCamera){
                p=pSwap(p);
                p=pRotate90(p, faceImg.height, faceImg.width);
            }
            
            p=pScale(p, widthScaleBy, heightScaleBy);
            
            [arrStrPoints addObject:NSStringFromCGPoint(p)];
            
        }
    }
    return arrStrPoints;

}


-(void)praseTrackResult:(NSString*)result OrignImage:(IFlyFaceImage*)faceImg{

    if(!result){
        return;
    }
    
    @try {
        NSError* error;
        NSData* resultData=[result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* faceDic=[NSJSONSerialization JSONObjectWithData:resultData options:NSJSONReadingMutableContainers error:&error];
        resultData=nil;
        if(!faceDic){
            return;
        }
            
        NSString* faceRet=[faceDic objectForKey:KCIFlyFaceResultRet];
        NSArray* faceArray=[faceDic objectForKey:KCIFlyFaceResultFace];
        faceDic=nil;
        
        int ret=0;
        if(faceRet){
            ret=[faceRet intValue];
        }
        //没有检测到人脸或发生错误
        if (ret || !faceArray || [faceArray count]<1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideFace];
            } ) ;
            return;
        }
        
        //检测到人脸
        
        NSMutableArray *arrPersons = [NSMutableArray array] ;
        
        for(id faceInArr in faceArray){
            
            if(faceInArr && [faceInArr isKindOfClass:[NSDictionary class]]){
                
                NSDictionary* positionDic=[faceInArr objectForKey:KCIFlyFaceResultPosition];
                NSString* rectString=[self praseDetect:positionDic OrignImage: faceImg];
                positionDic=nil;

                NSDictionary* landmarkDic=[faceInArr objectForKey:KCIFlyFaceResultLandmark];
                NSMutableArray* strPoints=[self praseAlign:landmarkDic OrignImage:faceImg];
                landmarkDic=nil;

                
                NSMutableDictionary *dicPerson = [NSMutableDictionary dictionary] ;
                if(rectString){
                    [dicPerson setObject:rectString forKey:RECT_KEY];
                }
                if(strPoints){
                    [dicPerson setObject:strPoints forKey:POINTS_KEY];
                }
                
                strPoints=nil;
                
                [dicPerson setObject:@"0" forKey:RECT_ORI];
                [arrPersons addObject:dicPerson] ;
                
                dicPerson=nil;
            
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showFaceLandmarksAndFaceRectWithPersonsArray:arrPersons];
                } ) ;
            }
        }
        
        
        // 人脸验证相关
        if (!self.isVerified && faceArray.count == 1) {
            self.isVerified = YES;
            
            
            UIImage * image = [faceImg.image fixOrientation:UIImageOrientationRight];
            [self saveImageToPhotos:image];
            [self faceVerify:image];
        }
        
        faceArray=nil;
    }
    @catch (NSException *exception) {
        NSLog(@"prase exception:%@",exception.name);
    }
    @finally {
    }
    
}

#pragma mark - CaptureManagerDelegate

-(void)onOutputFaceImage:(IFlyFaceImage*)faceImg{
    
    NSString* strResult=[self.faceDetector trackFrame:faceImg.data withWidth:faceImg.width height:faceImg.height direction:(int)faceImg.direction];
    NSLog(@"result:%@",strResult);
    
    //此处清理图片数据，以防止因为不必要的图片数据的反复传递造成的内存卷积占用。
    // 人脸验证相关
    //faceImg.data=nil;
    
//    if (self.faceCount > 10) {
//        [self didClickTakePhoto];
//        return;
//    }
    
    NSMethodSignature *sig = [self methodSignatureForSelector:@selector(praseTrackResult:OrignImage:)];
    if (!sig) return;
    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:sig];
    [invocation setTarget:self];
    [invocation setSelector:@selector(praseTrackResult:OrignImage:)];
    [invocation setArgument:&strResult atIndex:2];
    [invocation setArgument:&faceImg atIndex:3];
    [invocation retainArguments];
    [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil  waitUntilDone:NO];
    faceImg=nil;
}

-(void)observerContext:(CaptureContextType)type Changed:(BOOL)boolValue{
    
    switch(type){
        case CaptureContextTypeRunningAndDeviceAuthorized:{
            if (boolValue){
                self.isLockTap=NO;
            }
            else{
                self.isLockTap=YES;
            }
        }
            break;
        case CaptureContextTypeCameraFrontOrBackToggle:{
            if (boolValue){
                self.isLockTap=NO;
            }
            else{
                self.isLockTap=YES;
            }
        }
            break;
        default:
            break;
    }
}

#pragma mark 人脸验证
- (void)faceVerify:(UIImage*)faceImg {
    
    //@hanhd@add@停止摄像
//    [self.previewLayer.session stopRunning];
    
    
    self.resultStings=nil;
    self.resultStings=[[NSString alloc] init];
    

    [_activityIndicator startAnimating];
    [_activityIndicator setHidden:NO];
//    _backBtn.enabled=NO;
//    _imgSelectBtn.enabled=NO;
//    _settingBtn.enabled=NO;
//    _funcSelectBtn.enabled=NO;
//    _labelView.text=@"";
    
    [self.iFlySpFaceRequest setParameter:[IFlySpeechConstant FACE_VERIFY] forKey:[IFlySpeechConstant FACE_SST]];
    [self.iFlySpFaceRequest setParameter:USER_APPID forKey:[IFlySpeechConstant APPID]];
    [self.iFlySpFaceRequest setParameter:USER_APPID forKey:@"auth_id"];
    NSUserDefaults* userDefaults=[NSUserDefaults standardUserDefaults];
    NSString* gid=[userDefaults objectForKey:KCIFlyFaceResultGID];
    if(!gid){
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"结果" message:@"请先注册，或在设置中输入已注册的gid" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
        alert=nil;
        [_activityIndicator stopAnimating];
        [_activityIndicator setHidden:YES];
//        _backBtn.enabled=YES;
//        _imgSelectBtn.enabled=YES;
//        _settingBtn.enabled=YES;
//        _funcSelectBtn.enabled=YES;
        return;
    }
    [self.iFlySpFaceRequest setParameter:gid forKey:[IFlySpeechConstant FACE_GID]];
    [self.iFlySpFaceRequest setParameter:@"2000" forKey:@"wait_time"];
    //  压缩图片大小
    NSData* imgData=[faceImg compressedData];
    NSLog(@"verify image data length: %lu",(unsigned long)[imgData length]);
    [self.iFlySpFaceRequest sendRequest:imgData];
    
}

#pragma mark - Data Parser

-(void)praseVerifyResult:(NSString*)result{
    NSString *resultInfo = @"";
    NSString *resultInfoForLabel = @"";
    
    @try {
        NSError* error;
        NSData* resultData=[result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* dic=[NSJSONSerialization JSONObjectWithData:resultData options:NSJSONReadingMutableContainers error:&error];
        
        if(dic){
            NSString* strSessionType=[dic objectForKey:KCIFlyFaceResultSST];
            
            if([strSessionType isEqualToString:KCIFlyFaceResultVerify]){
                NSString* rst=[dic objectForKey:KCIFlyFaceResultRST];
                NSString* ret=[dic objectForKey:KCIFlyFaceResultRet];
                if([ret integerValue]!=0){
                    resultInfo=[resultInfo stringByAppendingFormat:@"验证错误\n错误码：%@",ret];
                }else{
                    
                    if([rst isEqualToString:KCIFlyFaceResultSuccess]){
                        resultInfo=[resultInfo stringByAppendingString:@"检测到人脸\n"];
                    }else{
                        resultInfo=[resultInfo stringByAppendingString:@"未检测到人脸\n"];
                    }
                    NSString* verf=[dic objectForKey:KCIFlyFaceResultVerf];
                    NSString* score=[dic objectForKey:KCIFlyFaceResultScore];
                    if([verf boolValue]){
                        resultInfoForLabel=[resultInfoForLabel stringByAppendingFormat:@"score:%@\n",score];
                        resultInfo=[resultInfo stringByAppendingString:@"验证结果:验证成功!"];
                        
                        [self performSelector:@selector(pop) withObject:nil afterDelay:2];
                    }else{
                        NSUserDefaults* defaults=[NSUserDefaults standardUserDefaults];
                        NSString* gid=[defaults objectForKey:KCIFlyFaceResultGID];
                        resultInfoForLabel=[resultInfoForLabel stringByAppendingFormat:@"last reg gid:%@\n",gid];
                        resultInfo=[resultInfo stringByAppendingString:@"验证结果:验证失败!"];
                        
                    }
                }
                
            }
            
//            _labelView.text=resultInfoForLabel;
//            _labelView.textColor=[UIColor redColor];
//            _labelView.hidden=NO;
            [_activityIndicator stopAnimating];
            [_activityIndicator setHidden:YES];
//            _backBtn.enabled=YES;
//            _imgSelectBtn.enabled=YES;
//            _settingBtn.enabled=YES;
//            _funcSelectBtn.enabled=YES;
            
            if([resultInfo length]<1){
                resultInfo=@"结果异常";
            }
            
            [self performSelectorOnMainThread:@selector(showResultInfo:) withObject:resultInfo waitUntilDone:NO];
        }
        
    }
    @catch (NSException *exception) {
        NSLog(@"prase exception:%@",exception.name);
    }
    @finally {
        
    }
    
    
}

#pragma mark - IFlyFaceRequestDelegate


/**
 * 消息回调
 * @param eventType 消息类型
 * @param params 消息数据对象
 */
- (void) onEvent:(int) eventType WithBundle:(NSString*) params{
    NSLog(@"onEvent | params:%@",params);
}

/**
 * 数据回调，可能调用多次，也可能一次不调用
 * @param buffer 服务端返回的二进制数据
 */
- (void) onData:(NSData* )data{
    
    NSLog(@"onData | ");
    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"result:%@",result);
    
    if (result) {
        self.resultStings=[self.resultStings stringByAppendingString:result];
    }
    
}

/**
 * 结束回调，没有错误时，error为null
 * @param error 错误类型
 */
- (void) onCompleted:(IFlySpeechError*) error{
    [_activityIndicator stopAnimating];
    [_activityIndicator setHidden:YES];
//    _backBtn.enabled=YES;
//    _imgSelectBtn.enabled=YES;
//    _settingBtn.enabled=YES;
//    _funcSelectBtn.enabled=YES;
    NSLog(@"onCompleted | error:%@",[error errorDesc]);
    NSString* errorInfo=[NSString stringWithFormat:@"错误码：%d\n 错误描述：%@",[error errorCode],[error errorDesc]];
    if(0!=[error errorCode]){
        [self performSelectorOnMainThread:@selector(showResultInfo:) withObject:errorInfo waitUntilDone:NO];
    }
    else{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateFaceImage:self.resultStings];
        });
    }
}

#pragma mark - Perform results On UI

-(void)updateFaceImage:(NSString*)result{
    
    NSError* error;
    NSData* resultData=[result dataUsingEncoding:NSUTF8StringEncoding];
    
    
    NSDictionary* dic=[NSJSONSerialization JSONObjectWithData:resultData options:NSJSONReadingMutableContainers error:&error];
    
    if(dic){
        NSString* strSessionType=[dic objectForKey:KCIFlyFaceResultSST];
        
//        //注册
//        if([strSessionType isEqualToString:KCIFlyFaceResultReg]){
//            [self praseRegResult:result];
//        }
        
        //验证
        if([strSessionType isEqualToString:KCIFlyFaceResultVerify]){
            [self praseVerifyResult:result];
        }
        
//        //检测
//        if([strSessionType isEqualToString:KCIFlyFaceResultDetect]){
//            [self praseDetectResult:result];
//        }
//
//        //关键点
//        if([strSessionType isEqualToString:KCIFlyFaceResultAlign]){
//            [self praseAlignResult:result];
//        }
        
    }
}


#pragma mark 人脸识别 辅助函数


-(void)showResultInfo:(NSString*)resultInfo{
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"结果" message:resultInfo delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
    [alert show];
    alert=nil;
}

-(void) pop{
    [self.navigationController popViewControllerAnimated:YES];
}

//实现该方法
- (void)saveImageToPhotos:(UIImage*)savedImage
{
    UIImageWriteToSavedPhotosAlbum(savedImage, self, @selector(image:didFinishSavingWithError:contextInfo:), (__bridge void *)self);
    //因为需要知道该操作的完成情况，即保存成功与否，所以此处需要一个回调方法image:didFinishSavingWithError:contextInfo:
}

//回调方法
- (void)image: (UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo
{
    NSLog(@"image = %@, error = %@, contextInfo = %@", image, error, contextInfo);
}

@end
