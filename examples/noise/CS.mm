#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
namespace stb_image {
    #import "../../stb_image_write.h"
}

#define UTF8StrWithFormat(fmt, ...) [[NSString stringWithFormat:fmt,##__VA_ARGS__] UTF8String]

#import "../../FileManager.h"
#import "../../MTLUtils.h"
#import "../../MTLReadPixels.h"
#import "../../ComputeShaderBase.h"



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
        
        T *exec(T *src,float t) {
            
            if(this->init()) {
                
                float *time = (float *)[this->_params[1] contents];
                time[0] = t;
                
                MTLReadPixels<T> *buffer = this->_buffer[DST_BUFFER];
                
                if(src) {
                    MTLUtils::replace(this->_texture[SRC_TEXTURE],src,buffer->width(),buffer->height(),buffer->rowBytes());
                }
        
                ComputeShaderBase<T>::update();
                this->_buffer[DST_BUFFER]->getBytes(this->_texture[DST_TEXTURE],true);
                
            }
        
            return this->bytes();
        }
        
        Test(int w,int h, int bpp, NSString *path) : ComputeShaderBase<T>(w,h) {
            
            this->_useArgumentEncoder = false;
            this->_buffer.push_back(new MTLReadPixels<T>(w,h,1));
            
            std::string type = @encode(T);
            
            MTLTextureDescriptor *descriptor = nil;
            
            if(type=="I"&&bpp==4) {
                descriptor = MTLUtils::descriptor(MTLPixelFormatRGBA8Unorm,w,h);
            }
            else if(type=="S"&&bpp==2) {
                descriptor = MTLUtils::descriptor(MTLPixelFormatRG16Unorm,w,h);
            }
            else if(type=="f") {
                if(bpp==1) descriptor = MTLUtils::descriptor(MTLPixelFormatR32Float,w,h);
                else if(bpp==2) descriptor = MTLUtils::descriptor(MTLPixelFormatRG32Float,w,h);
                else if(bpp==4) descriptor = MTLUtils::descriptor(MTLPixelFormatRGBA32Float,w,h);
            }
            
            if(descriptor) {
                
                descriptor.usage = MTLTextureUsageShaderWrite|MTLTextureUsageShaderRead;
                
                for(int k=0; k<TEXTURE_NUM; k++) {
                    this->_texture.push_back([this->_device newTextureWithDescriptor:descriptor]);
                }
                
                // resolution
                this->_params.push_back(MTLUtils::setFloat2((MTLUtils::newBuffer(this->_device,sizeof(float)*2)),w,h));

                // time
                this->_params.push_back(MTLUtils::newBuffer(this->_device,sizeof(float)*1));
                
                // scale
                this->_params.push_back(MTLUtils::setFloat(MTLUtils::newBuffer(this->_device,sizeof(float)*1),4.0));
                
                // offset 
                this->_params.push_back(MTLUtils::setFloat2((MTLUtils::newBuffer(this->_device,sizeof(float)*2)),0.5,0.5));
                            
                ComputeShaderBase<T>::setup(path);
            }
            else {
                NSLog(@"%s",type.c_str());
            }
        }
        
        ~Test() {
        }
};

class App {
    
    private:
    
        const unsigned int w = 1920;
        const unsigned int h = 1080;
    
        unsigned int *dst = new unsigned int[w*h];
    
        Test<float> *test;
        
    public:
      
        App() {

            int totalFrames = 30*10;
            
            for(int i=0; i<h; i++) {
                for(int j=0; j<w; j++) {
                    this->dst[i*w+j] = 0xFF0000FF;
                }
            }
            
            this->test = new Test<float>(w,h,1,@"test.metallib");
            
            for(int k=0; k<totalFrames; k++) {
                
                double then = CFAbsoluteTimeGetCurrent();
                
                float *tmp = this->test->exec(nullptr,k*(M_PI*2.0)/(double)totalFrames);
                
                for(int i=0; i<h; i++) {
                    for(int j=0; j<w; j++) {
                        int gris = tmp[i*w+j]*255.0;
                        this->dst[i*w+j] = 0xFF000000|gris<<16|gris<<8|gris;
                    }
                }
                
                NSLog(@"%f",CFAbsoluteTimeGetCurrent()-then);

                stb_image::stbi_write_png(UTF8StrWithFormat(@"%05d.png",k),w,h,4,this->dst,w*4);
            }
        }
        
        ~App() {
            delete[] this->dst;
        }
};

int main(int argc, char *argv[]) {
    @autoreleasepool {
        srandom(CFAbsoluteTimeGetCurrent());
        new App();
    }
}
