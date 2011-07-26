//
// Logitech Media Server Copyright 2003-2011 Logitech.
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License,
// version 2.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
//
//  mov123 - A very basic Quicktime decoder command line application.
//
//  usage:  mov123 <srcfile>
//
//  opens and decodes the first audio track from a QuickTime compatible file.  This includes
//  Movie files, m4a AAC files, AIFF, WAV and other formats supported natively by quicktime.
//  Sends to standard out the raw uncompressed audio data in stereo 44.1kS/sec 16bit.
//  Output goes to stdout
//
//  Todo:  - extract channel, sample rate, and sample size information from the movie for
//           use in reencoding later
//         - CLI options for:
//             - specifying output file
//             - output files for AIFF and WAV
//             - changing sample rate, sample size, channel count, codec
//			   - usage
//	 	   - be graceful about failures
//
//  Portions based on Apple's ConvertMovieSndTrack sample code.
//
//  Modified by Henry Mason to use MovieExport Data Procs 
//      (modification based on Adrian Bourke's (adrianb@bigpond.net.au) "Modified ConvertMovieSndTrack")

#include <stdio.h>
#include <fcntl.h>

//#include <io.h>


#ifdef WIN32
#include "stdafx.h"
#include "io.h"
#include "Movies.h"
//#include "SoundComponents.h"
#include "QuickTimeComponents.h"
#include "QTML.h"
#else
#include <QuickTime/QuickTime.h>
#include <QuickTime/QTML.h>
#endif

#define BailErr(x) {err = x; if (err != noErr) { fprintf(stderr, "Failed at line: %d\n", __LINE__); goto bail; } }

const UInt32 kMaxBufferSize =  64 * 1024;  // max size of input buffer

// functions
OSErr ConvertMovieSndTrack(const char* inFileToConvert);

typedef struct {
    ExtendedSoundComponentData 	compData;
    TimeValue 					currentTime;
    TimeValue 					duration;
    TimeValue 					timescale;
    Boolean 					isThereMoreSource;
    Boolean 					isSourceVBR;
    MovieExportGetDataUPP 		getDataProc;
    MovieExportGetPropertyUPP 	getPropertyProc;
    void 						*refCon;
    long 						trackID;
} SCFillBufferData, *SCFillBufferDataPtr;

FILE* outFile;

#ifdef WIN32
int _tmain(int argc, _TCHAR* argv[])
#else
int main(int argc, char *argv[])
#endif
{
	
//	FSSpec		theDestFSSpec;
	OSErr		result = 0;
	
	outFile = stdout;

#ifdef WIN32
	_setmode(_fileno(outFile), O_BINARY);	
	InitializeQTML(0);                        // Initialize QTML
#endif
	EnterMovies();

//	if (argc > 2) 
//		result = NativePathNameToFSSpec(argv[2], &theDestFSSpec, 0 /* flags */);
//	if (result) {printf("NativePathNameToFSSpec failed on dest file %s with  %d\n",  argv[2],  result); goto bail; }

	result = ConvertMovieSndTrack(argv[1]);
//bail:
	if (result != 0) { fprintf(stderr, "Conversion failed with error: %d\n", result); }
	return result;
}


#ifndef AVAILABLE_MAC_OS_X_VERSION_10_2_AND_LATER
#ifndef WIN32
	// these didn't make it into the QT6 framework for 10.1.x so include
	// them here if we're not on 10.2 or later - if you have a newer framework
	// or are building a carbon CFM version you shouldn't need these
	enum {
	  scSoundVBRCompressionOK       = 'cvbr', /* pointer to Boolean*/
	  scSoundInputSampleRateType    = 'ssir', /* pointer to UnsignedFixed*/
	  scSoundSampleRateChangeOK     = 'rcok', /* pointer to Boolean*/
	  scAvailableCompressionListType = 'avai' /* pointer to OSType Handle*/
	};
#endif
#endif


static TimeValue convertTime(TimeValue originalTime, TimeValue originalTimescale, TimeValue newTimescale)
{
    TimeValue newTime = 0;
    TimeRecord timeRecord;
    
    
    timeRecord.value.hi = 0;
    timeRecord.value.lo = originalTime;
    timeRecord.scale = originalTimescale;
    timeRecord.base = NULL;
    ConvertTimeScale(&timeRecord, newTimescale);	
    newTime = timeRecord.value.lo;
    
    return newTime;
}

// * ----------------------------
// SoundConverterFillBufferDataProc
//
// the callback routine that provides the SOURCE DATA for conversion - it provides data by setting
// outData to a pointer to a properly filled out ExtendedSoundComponentData structure
static pascal Boolean SoundConverterFillBufferDataProc(SoundComponentDataPtr *outData, void *inRefCon)
{
    SCFillBufferDataPtr pFillData = (SCFillBufferDataPtr)inRefCon;
    
    OSErr err;
    
    // if after getting the last chunk of data the total time is over the duration, we're done
    if (pFillData->currentTime >= pFillData->duration) {
        pFillData->isThereMoreSource = false;
        pFillData->compData.desc.buffer = NULL;
        pFillData->compData.desc.sampleCount = 0;
        pFillData->compData.bufferSize = 0;		
        pFillData->compData.commonFrameSize = 0;
    }
    
    if (pFillData->isThereMoreSource) {
	
        MovieExportGetDataParams getDataParams;
        
        
        getDataParams.recordSize = sizeof(MovieExportGetDataParams);
        getDataParams.trackID = pFillData->trackID;
        getDataParams.requestedTime = pFillData->currentTime;
        getDataParams.sourceTimeScale = pFillData->timescale;
        getDataParams.actualTime = 0;
        getDataParams.dataPtr = NULL;
        getDataParams.dataSize = 0;
        getDataParams.desc = NULL;
        getDataParams.descType = 0;
        getDataParams.descSeed = 0;
        getDataParams.requestedSampleCount = 0;
        getDataParams.actualSampleCount = 0;
        getDataParams.durationPerSample = 0;
        getDataParams.sampleFlags = 0; 
        
        err = InvokeMovieExportGetDataUPP(pFillData->refCon, &getDataParams, pFillData->getDataProc);
        
        if ((noErr != err) || (getDataParams.dataSize == 0)) {
            pFillData->isThereMoreSource = false;
            pFillData->compData.desc.buffer = NULL;
            pFillData->compData.desc.sampleCount = 0;
            pFillData->compData.bufferSize = 0;		
            pFillData->compData.commonFrameSize = 0;
            
            if ((err != noErr) && (getDataParams.dataSize > 0)) {
#ifdef WIN32
                fprintf(stderr, "InvokeMovieExportGetDataUPP - Failed in FillBufferDataProc");
#else
                DebugStr("\pInvokeMovieExportGetDataUPP - Failed in FillBufferDataProc");
#endif
            }
        }
        else {
            pFillData->currentTime += convertTime(getDataParams.actualSampleCount, (pFillData->compData.desc.sampleRate >> 16), pFillData->timescale) * getDataParams.durationPerSample;
        
            // Indicate whether we have more data in the source file. This is redundant with 
            // some of the other checks we do above, but proves to be necessary in some cases
            // (crashes were reported with Apple Lossless encoded files, for example).
            pFillData->isThereMoreSource = (pFillData->currentTime < pFillData->duration);

            // sampleCount is the number of PCM samples
            pFillData->compData.desc.sampleCount = getDataParams.actualSampleCount;
        
            // point to our sound data
            pFillData->compData.desc.buffer = (unsigned char *)getDataParams.dataPtr;
        
            // kExtendedSoundBufferSizeValid was specified - make sure this field is filled in correctly
            pFillData->compData.bufferSize = getDataParams.dataSize;
        
            // for VBR audio we specified the kExtendedSoundCommonFrameSizeValid flag - make sure this field is filled in correctly
            if (pFillData->isSourceVBR) pFillData->compData.commonFrameSize = getDataParams.dataSize / pFillData->compData.desc.sampleCount;
        }
    }
    
    // set outData to a properly filled out ExtendedSoundComponentData struct
    *outData = (SoundComponentDataPtr)&pFillData->compData;
    
    return (pFillData->isThereMoreSource);
}

// * ----------------------------
// ConvertMovieSndTrack
//
// this function does the actual work
OSErr ConvertMovieSndTrack(const char* inFileToConvert)
{
    SoundConverter			 mySoundConverter = NULL;
    
    Movie					 theSrcMovie = 0;
    
    Handle					 hSys7SoundData = NULL;
    
    Ptr						 theDecompressionParams = NULL;
    Handle 					 theCompressionParams = NULL;
    
    SoundDescription		 theSrcInputFormatInfo;
    SoundDescriptionV1Handle hSoundDescription = NULL;
    UnsignedFixed 			 theOutputSampleRate;
    SoundComponentData		 theInputFormat,
							 theOutputFormat;
    
    SCFillBufferData 		 scFillBufferData = { NULL };
    Ptr						 pDecomBuffer = NULL;
    
    Boolean					 isSoundDone = false;
    
    OSErr 					 err = noErr;
    
    ComponentInstance		 componentInstance = NULL;
    ComponentDescription	 compDesc;
    MovieExportGetDataParams getDataParams;
    
    UInt32 inputBytes, outputBytes, maxPacketSize;
    Boolean outputFormatIsVBR;
    
    CompressionInfo compressionFactor;
    
    if (strncmp(inFileToConvert, "http:", strlen("http:")) &&
        strncmp(inFileToConvert, "rtsp:", strlen("rtsp:")) &&
        strncmp(inFileToConvert, "ftp:", strlen("ftp:") )) {
        
        short theRefNum;
        short theResID = 0;	// we want the first movie
        Boolean wasChanged;
        
        FSSpec		theFSSpec;
        
#ifdef WIN32
        OSErr result = NativePathNameToFSSpec((char*)inFileToConvert, &theFSSpec, 0 /* flags */);
#else
        FSRef ref; // intermediate struct
        FSPathMakeRef( (const UInt8*)inFileToConvert, &ref, NULL );
        OSErr result = FSGetCatalogInfo( &ref, kFSCatInfoNone , NULL, NULL, &theFSSpec, NULL);
#endif
        if (result) {printf("NativePathNameToFSSpec failed on source file %s with %d\n", inFileToConvert, result); goto bail; }
        
        // open the movie file
        err = OpenMovieFile(&theFSSpec, &theRefNum, fsRdPerm);
        BailErr(err);
        
        // instantiate the movie
        err = NewMovieFromFile(&theSrcMovie, theRefNum, &theResID, NULL, newMovieActive, &wasChanged);
        CloseMovieFile(theRefNum);
        BailErr(err);
        
    } else {
        
        Handle urlDataRef; 
        
        urlDataRef = NewHandle((Size)strlen(inFileToConvert) + 1); 
        if ( ( err = MemError()) != noErr) goto bail; 
        
        BlockMoveData(inFileToConvert, *urlDataRef, (Size)strlen(inFileToConvert) + 1); 
        
        err = NewMovieFromDataRef(&theSrcMovie, newMovieActive, nil, urlDataRef, URLDataHandlerSubType); 
        if (err) {printf("NewMovieFrom Data Ref failed on source file %s with %d\n", inFileToConvert, err); goto bail; }
        
        DisposeHandle(urlDataRef); 
        
    }
    
    // *********** MOVIE: Find our Movie
    
    if (theSrcMovie)
    {
        
	// *********** MOVIEEXPORT DATA AND PROPERTIES PROCS: Set up the data source
	
        compDesc.componentType = MovieExportType;
        compDesc.componentSubType = kQTFileTypeMovie;
        compDesc.componentManufacturer = kAppleManufacturer;
        compDesc.componentFlags = canMovieExportFromProcedures | movieExportMustGetSourceMediaType;
        compDesc.componentFlagsMask = compDesc.componentFlags;
        
        if ((err = OpenAComponent(FindNextComponent(NULL, &compDesc), &componentInstance)) != noErr)
            BailErr(err);
        
        MovieExportNewGetDataAndPropertiesProcs(componentInstance,
                                                SoundMediaType,
                                                &scFillBufferData.timescale,
                                                theSrcMovie,
                                                NULL,
                                                0,
                                                GetMovieDuration(theSrcMovie),
                                                &scFillBufferData.getPropertyProc,
                                                &scFillBufferData.getDataProc, 
                                                &scFillBufferData.refCon);
        
        if (scFillBufferData.getDataProc == NULL || scFillBufferData.getPropertyProc == NULL)
            BailErr(paramErr);
        
        scFillBufferData.trackID = 0;
        getDataParams.recordSize = sizeof(MovieExportGetDataParams);
        getDataParams.trackID = scFillBufferData.trackID;
        getDataParams.requestedTime = 0;
        getDataParams.sourceTimeScale = scFillBufferData.timescale;
        getDataParams.actualTime = 0;
        getDataParams.dataPtr = NULL;
        getDataParams.dataSize = 0;
        getDataParams.desc = NULL;
        getDataParams.descType = 0;
        getDataParams.descSeed = 0;
        getDataParams.requestedSampleCount = 0;
        getDataParams.actualSampleCount = 0;
        getDataParams.durationPerSample = 1;
        getDataParams.sampleFlags = 0; 
        
        if ((err = InvokeMovieExportGetDataUPP(scFillBufferData.refCon, &getDataParams, scFillBufferData.getDataProc)) != noErr)
            BailErr(err);
        
        theSrcInputFormatInfo = **((SoundDescriptionHandle)getDataParams.desc);
        
        // setup input format for sound converter
        theInputFormat.flags = 0;
        theInputFormat.format = theSrcInputFormatInfo.dataFormat;
        theInputFormat.numChannels = theSrcInputFormatInfo.numChannels;
        theInputFormat.sampleSize = theSrcInputFormatInfo.sampleSize;
        theInputFormat.sampleRate = theSrcInputFormatInfo. sampleRate;
        theInputFormat.sampleCount = 0;
        theInputFormat.buffer = NULL;
        theInputFormat.reserved = 0;
        
        theOutputFormat.flags = kNoRealtimeProcessing;
        theOutputFormat.format = k16BitBigEndianFormat;
        theOutputFormat.numChannels = 2; // theInputFormat.numChannels;
        theOutputFormat.sampleSize = 16;
        theOutputFormat.sampleRate = 44100 << 16; //theInputFormat.sampleRate;
        theOutputFormat.sampleCount = 0;
        theOutputFormat.buffer = NULL;
        theOutputFormat.reserved = 0;
        
	// *********** SOUND CONVERTER: Open converter and prepare for buffer conversion...captain!
        
        err = SoundConverterOpen(&theInputFormat, &theOutputFormat, &mySoundConverter);
        BailErr(err);
        
        // tell the sound converter we're cool with VBR formats
        SoundConverterSetInfo(mySoundConverter, siClientAcceptsVBR, Ptr(true));															
        
        // set up the sound converters compression environment
        // pass down siCompressionSampleRate, siCompressionChannels then siCompressionParams
        SoundConverterSetInfo(mySoundConverter, siCompressionSampleRate, &theOutputFormat.sampleRate); // ignore errors
        SoundConverterSetInfo(mySoundConverter, siCompressionChannels, &theOutputFormat.numChannels);
        
        // set up the compression environment by passing in the 'magic' compression params aquired from
        // standard sound compression eariler
        if (theCompressionParams) {
            HLock(theCompressionParams);
            err = SoundConverterSetInfo(mySoundConverter, siCompressionParams, *theCompressionParams);
            BailErr(err);
            HUnlock(theCompressionParams);
        }
        
        // set up the decompresson environment by passing in the 'magic' decompression params
        if (theDecompressionParams) {
            // don't check for an error, if the decompressor didn't need the
            // decompression atom for whatever reason we should still be ok
            SoundConverterSetInfo(mySoundConverter, siDecompressionParams, theDecompressionParams);
        }
        
        // we need to know if the output sample rate was changed so we can write it in the image description
        // few codecs (but some) will implement this - MPEG4 for example may change the output sample rate if
        // the user selects a low bit rate -  ignore errors
        theOutputSampleRate = theOutputFormat.sampleRate;
        SoundConverterGetInfo(mySoundConverter, siCompressionOutputSampleRate, &theOutputSampleRate);
        
        err = SoundConverterBeginConversion(mySoundConverter);
        BailErr(err);
        
        // we need to get info about data/frame sizes 
        // good practice to fill in the size of this structure
        compressionFactor.recordSize = sizeof(compressionFactor);
        
        hSoundDescription = (SoundDescriptionV1Handle)NewHandleClear(sizeof(SoundDescriptionV1));	
        BailErr(MemError());
        
        err = SoundConverterGetInfo(mySoundConverter, siCompressionFactor, &compressionFactor);				
        BailErr(err);
        
        HLock((Handle)hSoundDescription);
        
        (*hSoundDescription)->desc.descSize		 = sizeof(SoundDescriptionV1);
        (*hSoundDescription)->desc.dataFormat	 = (long)theOutputFormat.format;	   // compression format
        (*hSoundDescription)->desc.resvd1		 = 0;								   // must be 0
        (*hSoundDescription)->desc.resvd2		 = 0;							       // must be 0
        (*hSoundDescription)->desc.dataRefIndex	 = 0;								   // 0 - we'll let AddMediaXXX determine the index
        (*hSoundDescription)->desc.version		 = 1;								   // set to 1
        (*hSoundDescription)->desc.revlevel		 = 0;								   // set to 0
        (*hSoundDescription)->desc.vendor		 = 0;
        (*hSoundDescription)->desc.numChannels	 = theOutputFormat.numChannels;		   // number of channels
        (*hSoundDescription)->desc.sampleSize	 = theOutputFormat.sampleSize;		   // bits per sample - everything but 8 bit can be set to 16
        (*hSoundDescription)->desc.compressionID = compressionFactor.compressionID;    // the compression ID (eg. variableCompression)
        (*hSoundDescription)->desc.packetSize	 = 0;								   // set to 0
        (*hSoundDescription)->desc.sampleRate	 = theOutputSampleRate;		   		   // the sample rate
                                                                                                   // version 1 stuff
        (*hSoundDescription)->samplesPerPacket 	 = compressionFactor.samplesPerPacket; // the samples per packet holds the PCM sample count per audio frame (packet)
        (*hSoundDescription)->bytesPerPacket 	 = compressionFactor.bytesPerPacket;   // the bytes per packet
        
        // bytesPerFrame isn't necessarily calculated for us and returned as part of the CompressionFactor - not all codecs that
        // implement siCompressionFactor fill out bytesPerFrame - so we do it here - note that VBR doesn't deserve this treatment
        // but it's not harmful, the Sound Manager would do calculations itself as part of GetCompressionInfo()
        // It should be noted that GetCompressionInfo() doesn't work for codecs that need configuration with 'magic' settings.
        // This requires explicit opening of the codec and the siCompressionFactor selector for SoundComponentGetInfo()
        (*hSoundDescription)->bytesPerFrame 	 = compressionFactor.bytesPerPacket * theOutputFormat.numChannels;
        (*hSoundDescription)->bytesPerSample 	 = compressionFactor.bytesPerSample;							
        
        // the theCompressionParams are not necessarily present
        if (theCompressionParams) {
            // a Sound Description can't be locked when calling AddSoundDescriptionExtension so make sure it's unlocked
            HUnlock((Handle)hSoundDescription);
            err = AddSoundDescriptionExtension((SoundDescriptionHandle)hSoundDescription, theCompressionParams, siDecompressionParams);	
            BailErr(err);
            HLock((Handle)hSoundDescription);
        }
        
        // VBR implies a different media layout, this will affect how AddMediaSample() is called below
        outputFormatIsVBR = ((*hSoundDescription)->desc.compressionID == variableCompression);
        
	// *********** SOUND CONVERTER: Create buffers and Convert Data
        
        // figure out sizes for the input and output buffers
        // the input buffer has to be large enough so GetMediaSample isn't going to fail
        // start with some rough numbers which should work well
        inputBytes = ((1000 + (theInputFormat.sampleRate >> 16)) * theInputFormat.numChannels) * 4;
        outputBytes = 0;
        maxPacketSize = 0;
        
        // ask about maximum packet size (or worst case packet size) so we don't allocate a destination (output)
        // buffer that's too small - an output buffer smaller than MaxPacketSize would be really bad - init maxPacketSize
        // to 0 so if the request isn't understood we can create a number (some multiple of maxPacketSize) and go from there
        // this is likely only implemented by VBR codecs so don't get anxious about it not being implemented
        SoundConverterGetInfo(mySoundConverter, siCompressionMaxPacketSize, &maxPacketSize);
        
        // start with this - you don't really need to use GetBufferSizes just as long as the output buffer is larger than
        // the MaxPacketSize if implemented - we use kMaxBufferSize which is 64k as a minimum
        SoundConverterGetBufferSizes(mySoundConverter, kMaxBufferSize, NULL, NULL, &outputBytes);
        
        if (0 == maxPacketSize)
            maxPacketSize = kMaxBufferSize;   // kMaxBufferSize is 64k
        
        if (inputBytes < kMaxBufferSize)	  // kMaxBufferSize is 64k
            inputBytes = kMaxBufferSize;	  // note this is still too small for DV (NTSC=120000, PAL=144000)
        
        if (outputBytes < maxPacketSize)	  
            outputBytes = maxPacketSize;
        
        // allocate conversion buffer
        pDecomBuffer = NewPtr(outputBytes);
        BailErr(MemError());
        
        // fill in struct that gets passed to SoundConverterFillBufferDataProc via the refcon
        // this includes the ExtendedSoundComponentData information		
        scFillBufferData.currentTime = 0;		
        scFillBufferData.duration = convertTime(GetMovieDuration(theSrcMovie), GetMovieTimeScale(theSrcMovie), scFillBufferData.timescale);
        scFillBufferData.isThereMoreSource = true;
        
        // if the source is VBR it means we're going to set the kExtendedSoundCommonFrameSizeValid
        // flag and use the commonFrameSize field in the FillBuffer callback
        scFillBufferData.isSourceVBR = (theSrcInputFormatInfo.compressionID == variableCompression);
        
        scFillBufferData.compData.desc = theInputFormat;
        scFillBufferData.compData.desc.flags = kExtendedSoundData;
        scFillBufferData.compData.recordSize = sizeof(ExtendedSoundComponentData);
        scFillBufferData.compData.extendedFlags = kExtendedSoundBufferSizeValid;
        if (scFillBufferData.isSourceVBR) scFillBufferData.compData.extendedFlags |= kExtendedSoundCommonFrameSizeValid;
        scFillBufferData.compData.bufferSize = 0;	// filled in during FillBuffer callback
        
        if (err == noErr) {	
            
            UInt32 outputFrames,
            actualOutputBytes,
            outputFlags,
            durationPerMediaSample,
            numberOfMediaSamples;
            
            SoundConverterFillBufferDataUPP theFillBufferDataUPP = NewSoundConverterFillBufferDataUPP(SoundConverterFillBufferDataProc);	
            
            while (!isSoundDone) {
                
                err = SoundConverterFillBuffer(mySoundConverter,		// a sound converter
                                               theFillBufferDataUPP,	// the callback UPP
                                               &scFillBufferData,		// refCon passed to FillDataProc
                                               pDecomBuffer,			// the destination data  buffer
                                               outputBytes,				// size of the destination buffer
                                               &actualOutputBytes,		// number of output bytes
                                               &outputFrames,			// number of output frames
                                               &outputFlags);			// FillBuffer retured advisor flags
                if (err) break;
                if((outputFlags & kSoundConverterHasLeftOverData) == false) {
                    isSoundDone = true;
                }
                
                // see if output buffer is filled so we can write some data	
                if (actualOutputBytes > 0) {					
                    // so, what are we going to pass to AddMediaSample?
                    // 
                    // for variableCompression, a media sample == an audio packet (compressed), this is also true for uncompressed audio
                    // for fixedCompression, a media sample is a portion of an audio packet - it is 1 / compInfo.samplesPerPacket worth
                    // of data, there's no way to access just a portion of the samples
                    // therefore, we need to know if our compression format is VBR or Fixed and make the correct calculations for
                    // either VBR or not - Fixed and uncompressed are treated the same
                    if (outputFormatIsVBR) {
                        numberOfMediaSamples = outputFrames;
                        durationPerMediaSample = compressionFactor.samplesPerPacket;
                    } else {		
                        numberOfMediaSamples = outputFrames * compressionFactor.samplesPerPacket;
                        durationPerMediaSample = 1;
                    }
                    
                    if (!fwrite(pDecomBuffer, actualOutputBytes, 1, outFile)) goto bail;
                    
                    if (err) break;
                }
                
            } // while
            
            SoundConverterEndConversion(mySoundConverter, pDecomBuffer, &outputFrames, &actualOutputBytes);
            
            // if there's any left over data write it out
            if (noErr == err && actualOutputBytes > 0) {
                // see above comments regarding these calculations
                if (outputFormatIsVBR) {
                    numberOfMediaSamples = outputFrames;
                    durationPerMediaSample = compressionFactor.samplesPerPacket;
                } else {		
                    numberOfMediaSamples = outputFrames * compressionFactor.samplesPerPacket;
                    durationPerMediaSample = 1;
                }
                
                if (!fwrite(pDecomBuffer, actualOutputBytes, 1, outFile)) goto bail;
                
                BailErr(err);
            }
            
			if (theFillBufferDataUPP) {
                DisposeSoundConverterFillBufferDataUPP(theFillBufferDataUPP);
			}
        }
    }
        
bail:
        if (mySoundConverter)
            SoundConverterClose(mySoundConverter);
        
        if (pDecomBuffer)
            DisposePtr(pDecomBuffer);
        
        if (theCompressionParams)
            DisposeHandle(theCompressionParams);
        
        if (theDecompressionParams)
            DisposePtr((Ptr)theDecompressionParams);
        
        if (hSoundDescription)
            DisposeHandle((Handle)hSoundDescription);
        
        if (scFillBufferData.getPropertyProc || scFillBufferData.getDataProc)
            MovieExportDisposeGetDataAndPropertiesProcs(componentInstance, scFillBufferData.getPropertyProc, scFillBufferData.getDataProc, scFillBufferData.refCon);
        
        if (componentInstance)
            CloseComponent(componentInstance);
        
        if (theSrcMovie)
            DisposeMovie(theSrcMovie);
        
        
        if (hSys7SoundData)
            DisposeHandle(hSys7SoundData);
        
        return err;
    
}
