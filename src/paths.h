#pragma once

#ifdef THEOS_PACKAGE_SCHEME_ROOTHIDE
#import <roothide.h>
#define PLRootPath(path) jbroot(path)
#else
#import <rootless.h>
#define PLRootPath(path) ROOT_PATH_NS(path)
#endif
