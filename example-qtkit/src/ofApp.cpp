#include "ofMain.h"
#include "ofxQTKitPlayer.h"

class ofApp : public ofBaseApp{
    ofxQTKitPlayer qt;
public:
    void setup()
    {
        ofSetVerticalSync(true);
        ofSetFrameRate(60);
        
        qt.load("fingers.mov", OF_QTKIT_DECODE_TEXTURE_ONLY );
    }
    
    void update()
    {
        qt.setFrame(ofGetFrameNum() % qt.getTotalNumFrames());
        qt.update();
    }
    void draw()
    {
        ofClear(0);
        qt.draw(0, 0);
    }
};

//========================================================================
int main( ){
    ofSetupOpenGL(1280,720,OF_WINDOW);            // <-------- setup the GL context
    
    // this kicks off the running of my app
    // can be OF_WINDOW or OF_FULLSCREEN
    // pass in width and height too:
    ofRunApp(new ofApp());
    
}
