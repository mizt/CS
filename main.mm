#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
namespace stb_image {
    #import "stb_image_write.h"
}

#import "FileManager.h"
#import "MTLUtils.h"
#import "MTLReadPixels.h"
#import "ComputeShaderBase.h"

template <typename T>
class Test : public ComputeShaderBase<T> {

    protected:
    
        const int SRC_TEXTURE = 0;
        const int DST_TEXTURE = 1;
        const int TEXTURE_NUM = 2;
    
        const int DST_BUFFER = 0;
    
    public:
        
        T *bytes() {
            return (T *)this->_buffer[DST_BUFFER]->bytes();
        }
        
        unsigned int *exec(T *src) {
            
            if(this->init()) {
                
                MTLReadPixels<T> *buffer = this->_buffer[DST_BUFFER];
                
                MTLUtils::replace(this->_texture[SRC_TEXTURE],src,buffer->width(),buffer->height(),buffer->rowBytes());
        
                ComputeShaderBase<T>::update();
                this->_buffer[DST_BUFFER]->getBytes(this->_texture[DST_TEXTURE],true);
                
            }
        
            return this->bytes();
        }
        
        
        Test(int w,int h,NSString *path) : ComputeShaderBase<T>(w,h) {
            
            this->_useArgumentEncoder = false;
            this->_buffer.push_back(new MTLReadPixels<unsigned int>(w,h,4,@"shaders"));
    
            MTLTextureDescriptor *descriptor = MTLUtils::descriptor(MTLPixelFormatRGBA8Unorm,w,h);
            descriptor.usage = MTLTextureUsageShaderWrite|MTLTextureUsageShaderRead;
            
            for(int k=0; k<TEXTURE_NUM; k++) {
                this->_texture.push_back([this->_device newTextureWithDescriptor:descriptor]);
            }
            
            ComputeShaderBase<T>::setup(path);
    
        }
        
        ~Test() {
        }
        
};

class App {
    
    private:
        
        dispatch_source_t timer;
    
        const unsigned int w = 1920;
        const unsigned int h = 1080;
    
        unsigned int *buffer = new unsigned int[w*h];
    
        Test<unsigned int> *test;
    
    public:
      
        App() {
            
            for(int i=0; i<h; i++) {
                for(int j=0; j<w; j++) {
                    this->buffer[i*w+j] = 0xFF0000FF;
                }
            }
            
            this->test = new Test<unsigned int>(w,h,FileManager::concat(@"shaders",@"test.metallib"));
            this->timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_queue_create("ENTER_FRAME",0));
            dispatch_source_set_timer(this->timer,dispatch_time(0,0),(1.0/30)*1000000000,0);
            dispatch_source_set_event_handler(this->timer,^{
                
                @autoreleasepool {
                    double then = CFAbsoluteTimeGetCurrent();
                    this->test->exec(this->buffer);
                    NSLog(@"%f",CFAbsoluteTimeGetCurrent()-then);
                }
            });
            if(this->timer) dispatch_resume(this->timer);
        }
        
        ~App() {
            if(this->timer){
                dispatch_source_cancel(this->timer);
                this->timer = nullptr;
            }
            delete[] this->buffer;
        }
};

@interface AppDelegate:NSObject <NSApplicationDelegate> {
    App *app;
}
@end

@implementation AppDelegate
-(void)applicationDidFinishLaunching:(NSNotification*)aNotification { app = new App(); }
-(void)applicationWillTerminate:(NSNotification *)aNotification { delete app; }
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        srandom(CFAbsoluteTimeGetCurrent());
        id app = [NSApplication sharedApplication];
        id delegat = [AppDelegate alloc];
        [app setDelegate:delegat];
        [app run];
    }
}
