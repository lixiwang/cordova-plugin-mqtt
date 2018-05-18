#import <Cordova/CDV.h>
#import <MQTT/MQTTClient.h> // MQTT
#import <MQTT/MQTTAsync.h>  // MQTT

@interface CordovaMqTTPlugin : CDVPlugin {
    NSString *topicValue;
    NSString *listenCallBackId;
}
@property (unsafe_unretained,nonatomic) MQTTAsync mqttClient;
@property (strong,nonatomic) NSString* mqttClientID;
@property (strong,nonatomic) NSString* mqttUsername;
@property (strong,nonatomic) NSString* mqttPassword;

- (void)connect:(CDVInvokedUrlCommand*)command;
@end

#pragma mark - C Private prototypes
void mqttConnectionSucceeded(void* context, MQTTAsync_successData* response);
void mqttConnectionFailed(void* context, MQTTAsync_failureData* response);
void mqttConnectionLost(void* context, char* cause);

void mqttSubscriptionSucceeded(void* context, MQTTAsync_successData* response);
void mqttSubscriptionFailed(void* context, MQTTAsync_failureData* response);
int mqttMessageArrived(void* context, char* topicName, int topicLen, MQTTAsync_message* message);
void mqttUnsubscriptionSucceeded(void* context, MQTTAsync_successData* response);
void mqttUnsubscriptionFailed(void* context, MQTTAsync_failureData* response);

void mqttPublishSucceeded(void* context, MQTTAsync_successData* response);
void mqttPublishFailed(void* context, MQTTAsync_failureData* response);

void mqttDisconnectionSucceeded(void* context, MQTTAsync_successData* response);
void mqttDisconnectionFailed(void* context, MQTTAsync_failureData* response);

@implementation CordovaMqTTPlugin

-(void)connect:(CDVInvokedUrlCommand*)command {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(arrivedMessage:) name:@"messageResult" object:nil];
    _mqttClient = NULL;
    listenCallBackId = command.callbackId;
    NSString *urlServer = [command.arguments objectAtIndex:0];
    _mqttClientID = [command.arguments objectAtIndex:1];
    __block int status;
    status = MQTTAsync_create(&_mqttClient, urlServer.UTF8String, _mqttClientID.UTF8String, MQTTCLIENT_PERSISTENCE_NONE, NULL);
    if (status != MQTTASYNC_SUCCESS) { return; }
    status = MQTTAsync_setCallbacks(_mqttClient, (__bridge void *)(self), mqttConnectionLost, mqttMessageArrived, NULL);
    if (status != MQTTASYNC_SUCCESS) { mqttDestroy((__bridge void *)(self)); }
    MQTTAsync_connectOptions connOptions = MQTTAsync_connectOptions_initializer;
    connOptions.onSuccess = mqttConnectionSucceeded;
    connOptions.onFailure = mqttConnectionFailed;
    connOptions.context = (__bridge void *)(self);
    status = MQTTAsync_connect(_mqttClient, &connOptions);
    if (status != MQTTASYNC_SUCCESS) { mqttDestroy((__bridge void *)(self));}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        CDVPluginResult* pluginResult = nil;
        if (status == MQTTASYNC_SUCCESS) { NSLog(@"Good");}
        if (status == MQTTASYNC_SUCCESS) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:@"connected", @"call", nil]];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        }
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    });
}

-(void)arrivedMessage:(NSNotification *)notification {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:notification.userInfo];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:listenCallBackId];
}

-(void)subscribe:(CDVInvokedUrlCommand*)command {
    NSString *topic = [command.arguments objectAtIndex:0];
    int status;
    MQTTAsync_responseOptions subOptions = MQTTAsync_responseOptions_initializer;
    subOptions.onSuccess = mqttSubscriptionSucceeded;
    subOptions.onFailure = mqttSubscriptionFailed;
    subOptions.context = (__bridge void *)(self);
    status = MQTTAsync_subscribe(_mqttClient, topic.UTF8String, 0, &subOptions);
    CDVPluginResult* pluginResult = nil;
    if (status == MQTTASYNC_SUCCESS)
        topicValue = topic;
    if (status == MQTTASYNC_SUCCESS) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:@"success", @"call", nil]];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)unsubscribe:(CDVInvokedUrlCommand*)command {

}

-(void)disconnect:(CDVInvokedUrlCommand*)command {

}

-(void)router:(CDVInvokedUrlCommand*)command {

}

-(void)publish:(CDVInvokedUrlCommand*)command {
    NSString *topicExtern = [command.arguments objectAtIndex:0];
    NSString *messageString = [command.arguments objectAtIndex:1];
    MQTTAsync_message message = MQTTAsync_message_initializer;
    message.payloadlen = (int)[messageString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    char payload[message.payloadlen];
    [messageString getCString:payload maxLength:message.payloadlen encoding:NSUTF8StringEncoding];
    message.payload = payload;
    MQTTAsync_responseOptions pubOptions = MQTTAsync_responseOptions_initializer;
    pubOptions.onSuccess = mqttPublishSucceeded;
    pubOptions.onFailure = mqttPublishFailed;
    pubOptions.context = (__bridge void *)(self);
    int status = MQTTAsync_sendMessage(_mqttClient, topicExtern.UTF8String, &message, &pubOptions);
    CDVPluginResult* pluginResult = nil;
    if (status == MQTTASYNC_SUCCESS) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:@"success", @"call", nil]];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark MQTT functions
void mqttConnectionSucceeded(void* context, MQTTAsync_successData* response) {
    dispatch_async(dispatch_get_main_queue(), ^{
        printf("MQTT connection to broker succeeded.\n");
    });
}
void mqttConnectionFailed(void* context, MQTTAsync_failureData* response) {
    printf("MQTT connection to broker failed.\n");
    mqttDestroy(context);
}

void mqttConnectionLost(void* context, char* cause) {
    printf("MQTT connection was lost with cause: %s\n", cause);
    mqttDestroy(context);
}

void mqttSubscriptionSucceeded(void* context, MQTTAsync_successData* response) {
    dispatch_async(dispatch_get_main_queue(), ^{
        printf("MQTT subscription succeeded to topic: \n");
    });
}

void mqttSubscriptionFailed(void* context, MQTTAsync_failureData* response) {
    dispatch_async(dispatch_get_main_queue(), ^{
        printf("MQTT subscription failed to topic:");
    });
}

int mqttMessageArrived(void* context, char* topicName, int topicLen, MQTTAsync_message* message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        printf("MQTT message arrived from topic: %s with body: %s\n", topicName, message->payload);
        NSString* topicNameDict = [NSString stringWithFormat:@"%s", topicName];
        NSString* messageDict = [NSString stringWithFormat:@"%s", message->payload];
        NSDictionary *temp = [NSDictionary dictionaryWithObjectsAndKeys:@"messageArrived", @"type", topicNameDict, @"topic", messageDict, @"payload", @"onPublish", @"call", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageResult" object:nil userInfo:temp];
    });
    return true;
}

void mqttUnsubscriptionSucceeded(void* context, MQTTAsync_successData* response) {
    dispatch_async(dispatch_get_main_queue(), ^{
        printf("MQTT unsubscription succeeded.\n");
    });
}

void mqttUnsubscriptionFailed(void* context, MQTTAsync_failureData* response) {
    dispatch_async(dispatch_get_main_queue(), ^{
        printf("MQTT unsubscription failed.\n");
    });
}

void mqttPublishSucceeded(void* context, MQTTAsync_successData* response) {
    dispatch_async(dispatch_get_main_queue(), ^{
        printf("MQTT publish message succeeded.\n");
    });
}

void mqttPublishFailed(void* context, MQTTAsync_failureData* response) {
    dispatch_async(dispatch_get_main_queue(), ^{
        printf("MQTT publish message failed.\n");
    });
}

void mqttDisconnectionSucceeded(void* context, MQTTAsync_successData* response) {
    printf("MQTT disconnection succeeded.\n");
    mqttDestroy(context);
}

void mqttDisconnectionFailed(void* context, MQTTAsync_failureData* response) {
    printf("MQTT disconnection failed.\n");
    mqttDestroy(context);
}

void mqttDestroy(void* context) {
    dispatch_async(dispatch_get_main_queue(), ^{
        printf("MQTT handler destroyed.\n");
    });
}


@end
