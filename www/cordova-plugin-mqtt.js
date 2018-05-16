/*
Adding new router config.
routerConfig:{
    router:type Object
    publishMethod:type String,
    useDefaultRouter:type Boolean
}*/
var exec = require('cordova/exec'), cordova = require('cordova'),
    channel = require('cordova/channel'),
    utils = require('cordova/utils');
var url, uname, pass, iscls, router, mqtt = null;
var isDefault, useJS = true;
exports.connect = function (args) {
    //SSL support is coming soon
    //var urgx = //(^(tcp|ssl|local)&?:\/\/[^\@_?!]+[^\s]+[^\.]+\:\d{2,})/g;
    var urgx = /(^(tcp|local)&?:\/\/[^\@_?!]+[^\s]+[^\.]+\:\d{2,})/g;
    if (args.port !== undefined) {
        url = args.url + ":" + args.port;
    } else {
        url = args.url;
    }
    if (args.willTopicConfig !== undefined) {
        if (args.willTopicConfig.retain === undefined) {
            args.willTopicConfig.retain = true;
        }
    } else {
        args.willTopicConfig = {};
    }
    if (args.isCleanSession === undefined) {
        iscls = true;
    } else {
        iscls = args.isCleanSession;
    }
    if (args.routerConfig !== undefined) {
        if (Object.keys(args.routerConfig).length > 0) {
            if (!args.routerConfig.useDefaultRouter && args.routerConfig.useDefaultRouter !== undefined) {
                if (args.routerConfig.router !== undefined) {
                    router = args.routerConfig.router;
                    isDefault = useDefaultRouter;
                } else {
                    console.error("Please set your topic router object");
                }
            } else {
                //using default topic router
                router = new ME();
            }

        } else {
            //setting mqtt-emitter instance as default router
            router = new ME();
        }
    } else {
        router = new ME();
    }
    if (url.length > 0 && urgx.exec(url) !== null) {
        exec(function (cd) {
            //console.log("data",cd);
            switch (cd.call) {
                case "connected":
                    delete cd.call;
                    if (args.success !== undefined) {
                        args.success(cd);
                    }
                    //cordova.fireDocumentEvent("connected",cd);
                    console.warn("Cordova Plugin Warning: The eventListner implmentation to read the published payloads shall be discontinued from the 0.3.0 version. Kindly take a note of this change.");
                    break;
                case "disconnected":
                    delete cd.call;
                    if (args.error !== undefined) {
                        args.error(cd);
                    }
                    //cordova.fireDocumentEvent("disconnected",cd);
                    break;
                case "failure":
                    delete cd.call;
                    if (args.onConnectionLost !== undefined) {
                        args.onConnectionLost(cd);
                    }
                    //cordova.fireDocumentEvent("failure",cd);
                    break;
                case "onPublish":
                    delete cd.call;
                    if (args.onPublish !== undefined) {
                        args.onPublish(cd.topic, cd.payload);
                    }
                    if (router !== null) {
                        if (args.routerConfig !== undefined) {
                            if (args.routerConfig.publishMethod !== undefined) {
                                router[args.routerConfig.publishMethod](cd.topic, cd.payload);
                            }

                        } else {
                            router.emit(cd.topic, cd.payload);
                        }

                    }
                    //cordova.fireDocumentEvent(cd.topic,cd);
                    break;
                default:
                    console.log(cd);
                    break;
            }
        }, function (e) {
            console.error(e);
        }, "CordovaMqTTPlugin", "connect", [url, args.clientId, (args.keepAlive === undefined ? 60000 : args.keepAlive), iscls, args.connectionTimeout || 30, args.username, args.password, args.willTopicConfig.topic, args.willTopicConfig.payload, args.willTopicConfig.qos || 0, (args.willTopicConfig.retain === undefined ? true : args.willTopicConfig.retain), args.version || "3.1.1"]);

    } else {
        console.error("Please provide the URL to connect. If entered then please check the URL format. We support only tcp:// & local:// protocols");
    }

};
exports.publish = function (args) {
    (args.retain === undefined) ? (args.retain = false) : "";
    if (args.topic.length > 0) {
        exec(function (data) {
            //console.log("data",data);
            //cordova.fireDocumentEvent(data);
            switch (data.call) {
                case "success":
                    delete data.call;
                    if (args.success !== undefined) {
                        args.success(data);
                    }

                    break;
                case "failure":
                    delete data.call;
                    if (args.success !== undefined) {
                        args.error(data);
                    }
                    break;
            }
        }, function (e) {
            if (args.error !== undefined) {
                args.error(e);
            }
        }, "CordovaMqTTPlugin", "publish", [args.topic, args.payload, args.qos || 0, args.retain]);

    } else {
        console.error("Please provide a topic string in topic argument");
    }
};
exports.subscribe = function (args) {
    (args.retain === undefined) ? args.retain = false : args.retain = true;
    if (args.topic.length > 0) {
        exec(function (data) {
            //console.log("data",data);
            switch (data.call) {
                case "success":
                    delete data.call;
                    if (args.success !== undefined) {
                        args.success(data);
                    }
                    break;
                case "failure":
                    delete data.call;
                    if (args.error !== undefined) {
                        args.error(data);
                    }

                    break;
            }
        }, function (e) {
            console.error(e);
            args.error(e);
        }, "CordovaMqTTPlugin", "subscribe", [args.topic, args.qos || 0]);

    } else {
        console.error("Please provide a topic string in topic argument");
    }

};
exports.unsubscribe = function (args) {
    if (args.topic.length > 0) {
        exec(function (data) {
            console.log("data", data);
            switch (data.call) {
                case "success":
                    delete data.call;
                    if (args.success !== undefined) {
                        args.success(data);
                    }
                    if (router !== null) {
                        router.removeListener(args.topic);
                    }
                    break;
                case "failure":
                    delete data.call;
                    if (args.error !== undefined) {
                        args.error(data);
                    }
                    break;
            }
        }, function (e) {
            console.error(e);
            args.error(e);
        }, "CordovaMqTTPlugin", "unsubscribe", [args.topic]);

    } else {
        console.error("Please provide a topic string in topic argument");
    }
};
exports.disconnect = function (args) {
    exec(function (data) {
        console.log("data", data);
        switch (data.call) {
            case "success":
                delete data.call;
                if (args.success !== undefined) {
                    args.success(data);
                }
                break;
            case "failure":
                delete data.call;
                if (args.error !== undefined) {
                    args.error(data);
                }
                break;
        }
    }, function (e) {
        console.error(e);
        args.error(e);
    }, "CordovaMqTTPlugin", "disconnect", []);
};
exports.router = function () {
    if (router !== null) {
        return router;
    } else {
        console.error("Router object seems to be destroyed");
    }
};
exports.listen = function (topic, cb) {
    if (router !== null) {
        router.on(topic, cb);
    } else {
        console.error("Router object seems to be destroyed");
    }
};
