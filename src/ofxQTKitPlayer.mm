//#ifdef OF_VIDEO_PLAYER_QTKIT

#include "ofxQTKitPlayer.h"

#include "Poco/String.h"

//--------------------------------------------------------------------
ofxQTKitPlayer::ofxQTKitPlayer() {
	moviePlayer = NULL;
	bNewFrame = false;
    bPaused = true;
	duration = 0.0f;
    speed = 1.0f;
	// default this to true so the player update behavior matches ofQuicktimePlayer
	bSynchronousSeek = true;
    
    pixelFormat = OF_PIXELS_RGB;
    currentLoopState = OF_LOOP_NORMAL;
}

//--------------------------------------------------------------------
ofxQTKitPlayer::~ofxQTKitPlayer() {
	close();	
}

//--------------------------------------------------------------------
bool ofxQTKitPlayer::load(string path){
	return load(path, OF_QTKIT_DECODE_PIXELS_ONLY);
}

//--------------------------------------------------------------------
bool ofxQTKitPlayer::load(string movieFilePath, ofQTKitDecodeMode mode) {
	if(mode != OF_QTKIT_DECODE_PIXELS_ONLY && mode != OF_QTKIT_DECODE_TEXTURE_ONLY && mode != OF_QTKIT_DECODE_PIXELS_AND_TEXTURE){
		ofLogError("ofxQTKitPlayer") << "loadMovie(): unknown ofQTKitDecodeMode mode";
		return false;
	}
	
	if(isLoaded()){
		close(); //auto released 
	}

	BOOL success = NO;
	@autoreleasepool {
		decodeMode = mode;
		bool useTexture = (mode == OF_QTKIT_DECODE_TEXTURE_ONLY || mode == OF_QTKIT_DECODE_PIXELS_AND_TEXTURE);
		bool usePixels  = (mode == OF_QTKIT_DECODE_PIXELS_ONLY  || mode == OF_QTKIT_DECODE_PIXELS_AND_TEXTURE);
		bool useAlpha = (pixelFormat == OF_PIXELS_RGBA);

		bool isURL = false;

		if (Poco::icompare(movieFilePath.substr(0,7), "http://")  == 0 ||
			Poco::icompare(movieFilePath.substr(0,8), "https://") == 0 ||
			Poco::icompare(movieFilePath.substr(0,7), "rtsp://")  == 0) {
			isURL = true;
		}
		else {
			movieFilePath = ofToDataPath(movieFilePath, false);
		}

		moviePlayer = [[QTKitMovieRenderer alloc] init];
		success = [moviePlayer loadMovie:[NSString stringWithCString:movieFilePath.c_str() encoding:NSUTF8StringEncoding]
                               pathIsURL:isURL
                            allowTexture:useTexture
                             allowPixels:usePixels
                              allowAlpha:useAlpha];

		if(success){
			moviePlayer.synchronousSeek = bSynchronousSeek;
			reallocatePixels();
			moviePath = movieFilePath;
			duration = moviePlayer.duration;

			setLoopState(currentLoopState);
			setSpeed(1.0f);
			firstFrame(); //will load the first frame
		}
		else {
			ofLogError("ofxQTKitPlayer") << "loadMovie(): couldn't load \"" << movieFilePath << "\"";
			[moviePlayer release];
			moviePlayer = NULL;
		}
	}

	return success;
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::closeMovie() {
	close();
}

//--------------------------------------------------------------------
bool ofxQTKitPlayer::isLoaded() const {
	return moviePlayer != NULL;
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::close() {
	
	if(isLoaded()){
		@autoreleasepool {
			[moviePlayer release];
			moviePlayer = NULL;
		}
	}
	
	pixels.clear();
	duration = 0;
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::setPaused(bool _bPaused){
	if(!isLoaded()) return;

	bPaused = _bPaused;

	@autoreleasepool {
		if (bPaused) {
			[moviePlayer setRate:0.0f];
		} else {
			[moviePlayer setRate:speed];
		}
	}
}

//--------------------------------------------------------------------
bool ofxQTKitPlayer::isPaused() const {
	return bPaused;
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::stop() {
	setPaused(true);
}

//--------------------------------------------------------------------
bool ofxQTKitPlayer::isPlaying() const {
    if(!isLoaded()) return false;

	return !moviePlayer.isFinished && !isPaused(); 
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::firstFrame(){
	if(!isLoaded()) return;

	@autoreleasepool {
		[moviePlayer gotoBeginning];
		bHavePixelsChanged = bNewFrame = bSynchronousSeek;
	}
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::nextFrame(){
	if(!isLoaded()) return;

	@autoreleasepool {
		[moviePlayer stepForward];
		bHavePixelsChanged = bNewFrame = bSynchronousSeek;
	}
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::previousFrame(){
	if(!isLoaded()) return;

	@autoreleasepool {
		[moviePlayer stepBackward];
		bHavePixelsChanged = bNewFrame = bSynchronousSeek;
	}
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::setSpeed(float rate){
	if(!isLoaded()) return;

	speed = rate;

	if(isPlaying()) {
		@autoreleasepool {
			[moviePlayer setRate:rate];
		}
	}
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::play(){
	if(!isLoaded()) return;

	bPaused = false;

	@autoreleasepool {
		[moviePlayer setRate:speed];
	}
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::idleMovie() {
	update();
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::update() {
	if(!isLoaded()) return;

	@autoreleasepool {
		bNewFrame = [moviePlayer update];
		if (bNewFrame) {
			bHavePixelsChanged = true;
		}
	}
}

//--------------------------------------------------------------------
bool ofxQTKitPlayer::isFrameNew() const {
	return bNewFrame;
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::draw(float x, float y) {
	draw(x,y, moviePlayer.movieSize.width, moviePlayer.movieSize.height);
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::draw(float x, float y, float w, float h) {
	updateTexture();
	tex.draw(x,y,w,h);	
}

//--------------------------------------------------------------------
ofPixels& ofxQTKitPlayer::getPixels(){
	@autoreleasepool {
		if(isLoaded() && moviePlayer.usePixels) {
			//don't get the pixels every frame if it hasn't updated
			if(bHavePixelsChanged){
				[moviePlayer pixels:pixels.getPixels()];
				bHavePixelsChanged = false;
			}
		}
		else{
			ofLogError("ofxQTKitPlayer") << "getPixels(): returning pixels that may be unallocated, make sure to initialize the video player before calling this function";
		}
	}
	return pixels;
}

const ofPixels& ofxQTKitPlayer::getPixels() const {
    return pixels;
}

//--------------------------------------------------------------------
ofTexture* ofxQTKitPlayer::getTexturePtr() {
    ofTexture* texPtr = NULL;
	if(moviePlayer.textureAllocated){
		updateTexture();
        return &tex;
	} else {
        return NULL;
    }
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::setPosition(float pct) {
	if(!isLoaded()) return;

	@autoreleasepool {
		[moviePlayer setPosition:pct];
	}

	bHavePixelsChanged = bNewFrame = bSynchronousSeek;
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::setVolume(float volume) {
	if(!isLoaded()) return;

	@autoreleasepool {
		[moviePlayer setVolume:volume];
	}
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::setBalance(float balance) {
	if(!isLoaded()) return;
	
	@autoreleasepool {
		[moviePlayer setBalance:balance];
	}
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::setFrame(int frame) {
	if(!isLoaded()) return;

	frame %= [moviePlayer frameCount];

	@autoreleasepool {
		[moviePlayer setFrame:frame];
	}

	bHavePixelsChanged = bNewFrame = bSynchronousSeek;
}

//--------------------------------------------------------------------
int ofxQTKitPlayer::getCurrentFrame() const {
	if(!isLoaded()) return 0;
    return [moviePlayer frame];
}

//--------------------------------------------------------------------
int ofxQTKitPlayer::getTotalNumFrames() const {
	if(!isLoaded()) return 0;
	return [moviePlayer frameCount];
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::setLoopState(ofLoopType state) {
	if(!isLoaded()) return;

	@autoreleasepool {
		currentLoopState = state;

		if(state == OF_LOOP_NONE){
			[moviePlayer setLoops:false];
			[moviePlayer setPalindrome:false];
		}
		else if(state == OF_LOOP_NORMAL){
			[moviePlayer setLoops:true];
			[moviePlayer setPalindrome:false];
		}
		else if(state == OF_LOOP_PALINDROME) {
			[moviePlayer setLoops:false];
			[moviePlayer setPalindrome:true];
		}
	}
}

//--------------------------------------------------------------------
ofLoopType ofxQTKitPlayer::getLoopState() const {
	if(!isLoaded()) return OF_LOOP_NONE;
	
	ofLoopType state = OF_LOOP_NONE;
	
    if(![moviePlayer loops] && ![moviePlayer palindrome]){
		state = OF_LOOP_NONE;
	}
	else if([moviePlayer loops] && ![moviePlayer palindrome]){
		state =  OF_LOOP_NORMAL;
	}
	else if([moviePlayer loops] && [moviePlayer palindrome]) {
    	state = OF_LOOP_PALINDROME;
	}
	else{
		ofLogError("ofxQTKitPlayer") << "unknown loop state";
	}
	
	return state;
}

//--------------------------------------------------------------------
float ofxQTKitPlayer::getSpeed() const {
	return speed;
}

//--------------------------------------------------------------------
float ofxQTKitPlayer::getDuration() const {
	return duration;
}

//--------------------------------------------------------------------
float ofxQTKitPlayer::getPositionInSeconds() const {
	return getPosition() * duration;
}

//--------------------------------------------------------------------
float ofxQTKitPlayer::getPosition() const {
	if(!isLoaded()) return 0;
	return [moviePlayer position];
}

//--------------------------------------------------------------------
bool ofxQTKitPlayer::getIsMovieDone() const {
	if(!isLoaded()) return false;
	return [moviePlayer isFinished];
}

//--------------------------------------------------------------------
float ofxQTKitPlayer::getWidth() const {
    return [moviePlayer movieSize].width;
}

//--------------------------------------------------------------------
float ofxQTKitPlayer::getHeight() const {
    return [moviePlayer movieSize].height;
}

//--------------------------------------------------------------------
bool ofxQTKitPlayer::setPixelFormat(ofPixelFormat newPixelFormat){
    if(newPixelFormat != OF_PIXELS_RGB && newPixelFormat != OF_PIXELS_RGBA) {
        ofLogWarning("ofxQTKitPlayer") << "setPixelFormat(): pixel format " << newPixelFormat << " is not supported";
        return false;
    }

    if(newPixelFormat != pixelFormat){
        pixelFormat = newPixelFormat;
        // If we already have a movie loaded we need to reload
        // the movie with the new settings correctly allocated.
        if(isLoaded()){
            load(moviePath, decodeMode);
        }
    }	
	return true;
}

//--------------------------------------------------------------------
ofPixelFormat ofxQTKitPlayer::getPixelFormat() const {
	return pixelFormat;
}

//--------------------------------------------------------------------
ofQTKitDecodeMode ofxQTKitPlayer::getDecodeMode() const {
    return decodeMode;
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::setSynchronousSeeking(bool synchronous){
	bSynchronousSeek = synchronous;
    if(isLoaded()){
        moviePlayer.synchronousSeek = synchronous;
    }
}

//--------------------------------------------------------------------
bool ofxQTKitPlayer::getSynchronousSeeking() const {
	return bSynchronousSeek;
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::reallocatePixels(){
    if(pixelFormat == OF_PIXELS_RGBA){
        pixels.allocate(getWidth(), getHeight(), OF_IMAGE_COLOR_ALPHA);
    } else {
        pixels.allocate(getWidth(), getHeight(), OF_IMAGE_COLOR);
    }
}

//--------------------------------------------------------------------
void ofxQTKitPlayer::updateTexture(){
	if(moviePlayer.textureAllocated){
	   		
		tex.setUseExternalTextureID(moviePlayer.textureID); 
		
		ofTextureData& data = tex.getTextureData();
		data.textureTarget = moviePlayer.textureTarget;
		data.width = getWidth();
		data.height = getHeight();
		data.tex_w = getWidth();
		data.tex_h = getHeight();
		data.tex_t = getWidth();
		data.tex_u = getHeight();
	}
}

//#endif
