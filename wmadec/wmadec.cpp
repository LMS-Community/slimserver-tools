
/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* ***** BEGIN LICENSE BLOCK *****
* Version: MPL 1.1/GPL 2.0/LGPL 2.1
*
* The contents of this file are subject to the Mozilla Public
* License Version 1.1 (the "License"); you may not use this file
* except in compliance with the License. You may obtain a copy of
* the License at http://www.mozilla.org/MPL/
* 
* Software distributed under the License is distributed on an "AS
* IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
* implied. See the License for the specific language governing
* rights and limitations under the License.
* 
* The Original Code is the Command-line WMA decoder.
* 
* The Initial Developer of the Original Code is Vidur Apparao.
* Portions created by the Initial Developer are Copyright (C) 2004
* the Initial Developer. All Rights Reserved.
* 
* Contributor(s):
* 
* Alternatively, the contents of this file may be used under the
* terms of the GNU General Public License Version 2 or later (the
* "GPL"), in which case the provisions of the GPL are applicable 
* instead of those above.  If you wish to allow use of your 
* version of this file only under the terms of the GPL and not to
* allow others to use your version of this file under the MPL,
* indicate your decision by deleting the provisions above and
* replace them with the notice and other provisions required by
* the GPL.  If you do not delete the provisions above, a recipient
* may use your version of this file under either the MPL or the
* GPL.
*
* ***** END LICENSE BLOCK ***** */


#include "stdafx.h"
#include "getopt.h"

#define ONE_SECOND (QWORD)10000000
static char* gOptionStr = "dqhwb:r:n:o:l:";
#define STREAM_BUFFER_SIZE 1024

DWORD dwTotalSize = 0;
BOOL bDebug = FALSE;

class WMAStream : public IStream {
public:

  WMAStream(FILE* pFile);

  // IUnknown methods
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **ppvObject);
  ULONG STDMETHODCALLTYPE AddRef();
  ULONG STDMETHODCALLTYPE Release();
  
  // IStream methods
  HRESULT STDMETHODCALLTYPE Read(void *pv, ULONG cb, ULONG *pcbRead);
  HRESULT STDMETHODCALLTYPE Seek(LARGE_INTEGER dlibMove, 
                                 DWORD dwOrigin, 
                                 ULARGE_INTEGER *plibNewPosition);
  HRESULT STDMETHODCALLTYPE Stat(STATSTG *pstatstg, DWORD grfStatFlag);
  
  // Unimplemented methods of IStream
  HRESULT STDMETHODCALLTYPE Write(void const *pv, 
                                  ULONG cb, 
                                  ULONG *pcbWritten ) {
    return(E_NOTIMPL);
  }
  HRESULT STDMETHODCALLTYPE SetSize(ULARGE_INTEGER libNewSize) {
    return(E_NOTIMPL);
  }
  HRESULT STDMETHODCALLTYPE CopyTo(IStream *pstm, 
                                   ULARGE_INTEGER cb, 
                                   ULARGE_INTEGER *pcbRead, 
                                   ULARGE_INTEGER *pcbWritten) {
    return(E_NOTIMPL);
  }
  HRESULT STDMETHODCALLTYPE Commit(DWORD grfCommitFlags) {
    return(E_NOTIMPL);
  }
  HRESULT STDMETHODCALLTYPE Revert() {
    return(E_NOTIMPL);
  }
  HRESULT STDMETHODCALLTYPE LockRegion(ULARGE_INTEGER libOffset, 
                                       ULARGE_INTEGER cb, 
                                       DWORD dwLockType) {
    return(E_NOTIMPL);
  }
  HRESULT STDMETHODCALLTYPE UnlockRegion(ULARGE_INTEGER libOffset, 
                                         ULARGE_INTEGER cb, 
                                         DWORD dwLockType) {
    return(E_NOTIMPL);
  }
  HRESULT STDMETHODCALLTYPE Clone(IStream **ppstm) {
    return(E_NOTIMPL);
  }

protected:
  ~WMAStream();

  LONG    m_cRef;
  FILE*   m_pFile;
  BYTE    m_pBuf[STREAM_BUFFER_SIZE];
  size_t    m_lBytes;
  size_t    m_lPosition;
};

WMAStream::WMAStream(FILE* pFile) 
  :  m_pFile(pFile) {
  m_cRef = 0;
  m_lBytes = m_lPosition = 0;
}

WMAStream::~WMAStream() {
}

HRESULT STDMETHODCALLTYPE 
WMAStream::QueryInterface(REFIID iid,
                          void **ppvObject) {
  HRESULT hr = S_OK;
        
  if(NULL == ppvObject) {
    hr = E_POINTER;
  }
  else {
    *ppvObject = NULL;
  }
        
  if(SUCCEEDED(hr)) {
    if(IsEqualIID(iid, IID_IUnknown) || 
       IsEqualIID(iid, IID_IStream)) {
      *ppvObject = static_cast<IStream*>(this);
      AddRef();
    }
    else {
      hr = E_NOINTERFACE;
    }
  }
        
  return hr;
}

ULONG STDMETHODCALLTYPE 
WMAStream::AddRef() {
  return ::InterlockedIncrement(&m_cRef);
}

ULONG STDMETHODCALLTYPE 
WMAStream::Release() {
  LONG lRefCount = ::InterlockedDecrement(&m_cRef);
  if(0 == lRefCount) {
    delete this;
  }
        
  return lRefCount;
}

HRESULT STDMETHODCALLTYPE 
WMAStream::Read(void *pv, ULONG cb, ULONG *pcbRead) {

  size_t numread = fread(pv, sizeof(char), (size_t)cb, m_pFile);

  if (pcbRead) {
    *pcbRead = (ULONG)numread;
  }

  if (ferror(m_pFile)) {
    fprintf(stderr, "Reading from stream failed with error %d\n", 
            ferror(m_pFile));
    return S_FALSE;
  }

  return S_OK;
}

HRESULT STDMETHODCALLTYPE 
WMAStream::Seek(LARGE_INTEGER dlibMove, 
                DWORD dwOrigin, 
                ULARGE_INTEGER *plibNewPosition) {
  return E_FAIL;
}

HRESULT STDMETHODCALLTYPE 
WMAStream::Stat(STATSTG *pstatstg, DWORD grfStatFlag) {

  if(!pstatstg || (grfStatFlag != STATFLAG_NONAME)) {
    return E_INVALIDARG;
  }

  memset(pstatstg, 0, sizeof(STATSTG));
  
  pstatstg->type = STGTY_STREAM;
  pstatstg->cbSize.LowPart = 0;

  return S_OK;
}

class WMAReader : public IWMReaderCallback, IWMReaderCallbackAdvanced {
public:
  WMAReader(WORD wBitsPerSample,
            DWORD dwSamplesPerSec,
            DWORD dwNumChannels);

  // Two versions, one that takes a file (or URL) name, the other that
  // takes a stream. The stream path is currently used when getting
  // input from stdin.
  HRESULT Decode(LPCSTR lpInput, FILE* pOutput);
  HRESULT Decode(IStream* lpInput, FILE* pOutput); 

  // IUnknown methods
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **ppvObject);
  ULONG STDMETHODCALLTYPE AddRef();
  ULONG STDMETHODCALLTYPE Release();
  
  // IWMReaderCallback methods
  HRESULT STDMETHODCALLTYPE OnSample(DWORD dwOutputNum,
                                     QWORD cnsSampleTime,
                                     QWORD cnsSampleDuration,
                                     DWORD dwFlags,
                                     INSSBuffer __RPC_FAR *pSample,
                                     void __RPC_FAR *pvContext);
  HRESULT STDMETHODCALLTYPE OnStatus(WMT_STATUS Status,
                                     HRESULT hr,
                                     WMT_ATTR_DATATYPE dwType,
                                     BYTE __RPC_FAR *pValue,
                                     void __RPC_FAR *pvContext);

  // IWMReaderCallbackAdvanced methods
  HRESULT STDMETHODCALLTYPE OnStreamSample(WORD wStreamNum,
                                           QWORD cnsSampleTime,
                                           QWORD cnsSampleDuration,
                                           DWORD dwFlags,
                                           INSSBuffer *pSample,
                                           void *pvContext) {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnTime(QWORD cnsCurrentTime,
                                   void *pvContext);
  HRESULT STDMETHODCALLTYPE OnStreamSelection(WORD wStreamCount,
                                              WORD *pStreamNumbers,
                                              WMT_STREAM_SELECTION *pSelections,
                                              void *pvContext) {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnOutputPropsChanged(DWORD dwOutputNum,
                                                 WM_MEDIA_TYPE *pMediaType,
                                                 void *pvContext) {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE AllocateForStream(WORD wStreamNum,
                                              DWORD cbBuffer,
                                              INSSBuffer **ppBuffer,
                                              void *pvContext) {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE AllocateForOutput(DWORD dwOutputNum,
                                              DWORD cbBuffer,
                                              INSSBuffer **ppBuffer,
                                              void *pvContext) {
    return S_OK;
  }


protected:
  ~WMAReader();
  HRESULT Init(FILE* pOutput);
  HRESULT StartReading();

  LONG m_cRef;
  BOOL m_bInited;

  WORD m_wBitsPerSample;
  DWORD m_dwSamplesPerSec;
  DWORD m_dwNumChannels;
  BOOL m_bMakeStereo;
  
  IWMReader* m_pReader;
  IWMReaderAdvanced* m_pReaderAdvanced;
  FILE* m_pOutput;
  HANDLE m_hEvent;
  HRESULT m_hrAsync;
  DWORD m_dwOutputNum;
  QWORD m_qwReaderTime;
};

WMAReader::WMAReader(WORD wBitsPerSample,
                     DWORD dwSamplesPerSec,
                     DWORD dwNumChannels)
  : m_wBitsPerSample(wBitsPerSample), m_dwSamplesPerSec(dwSamplesPerSec),
  m_dwNumChannels(dwNumChannels) {
  m_cRef = 0;
  m_pReader = NULL;
  m_pReaderAdvanced = NULL;
  m_bInited = FALSE;
  m_hEvent = NULL;
  m_hrAsync = S_OK;
  m_dwOutputNum = -1;
  m_qwReaderTime = (QWORD)0;
  m_bMakeStereo = FALSE;
}

WMAReader::~WMAReader() {
  if (m_pReader) {
    m_pReader->Release();
  }
  if (m_pReaderAdvanced) {
    m_pReaderAdvanced->Release();
  }
  if (m_hEvent) {
    CloseHandle(m_hEvent);
  }
}

HRESULT STDMETHODCALLTYPE 
WMAReader::QueryInterface(REFIID iid,
                          void  **ppvObject) {
  HRESULT hr = S_OK;
        
  if(NULL == ppvObject) {
    hr = E_POINTER;
  }
  else {
    *ppvObject = NULL;
  }
        
  if(SUCCEEDED(hr)) {
    if(IsEqualIID(iid, IID_IUnknown) || 
       IsEqualIID(iid, IID_IWMReaderCallback)) {
      *ppvObject = static_cast<IWMReaderCallback*>(this);
      AddRef();
    }
    else if (IsEqualIID(iid, IID_IWMReaderCallbackAdvanced)) {
      *ppvObject = static_cast<IWMReaderCallbackAdvanced*>(this);
      AddRef();
    }
    else {
      hr = E_NOINTERFACE;
    }
  }
        
  return hr;
}

ULONG STDMETHODCALLTYPE 
WMAReader::AddRef() {
  return ::InterlockedIncrement(&m_cRef);
}

ULONG STDMETHODCALLTYPE 
WMAReader::Release() {
  LONG lRefCount = ::InterlockedDecrement(&m_cRef);
  if(0 == lRefCount) {
    delete this;
  }
        
  return lRefCount;
}

HRESULT
WMAReader::Init(FILE* pOutput) {
  HRESULT hr = S_OK;
  if (!m_bInited) {
    hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    if(FAILED(hr)) {
      fprintf(stderr, "COM initialization failed with error code 0x%x\n", hr);
      return hr;
    }

    hr = WMCreateReader(NULL, WMT_RIGHT_PLAYBACK, &m_pReader);
    if (FAILED(hr)) {
      fprintf(stderr, "Creating WMA reader failed with error code 0x%x\n", hr);
      return hr;
    }

    hr = m_pReader->QueryInterface(IID_IWMReaderAdvanced, 
                                   (void**)&m_pReaderAdvanced);
    if (FAILED(hr)) {
      fprintf(stderr, "Error QIing WMA reader 0x%x\n", hr);
      return hr;
    }
    
    m_hEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
    if (!m_hEvent) {
      hr = HRESULT_FROM_WIN32(GetLastError());
      fprintf(stderr, "Creating Win32 Event failed with error code 0x%x\n", 
              hr);
      return hr;
    }
    m_pOutput = pOutput;
    m_bInited = TRUE;
  }

  return hr;
}

HRESULT STDMETHODCALLTYPE 
WMAReader::OnSample(DWORD dwOutputNum,
                    QWORD cnsSampleTime,
                    QWORD cnsSampleDuration,
                    DWORD dwFlags,
                    INSSBuffer __RPC_FAR *pSample,
                    void __RPC_FAR *pvContext) {

  if (bDebug) {
    fprintf(stderr, "cnsSampleTime: [%d]\n", cnsSampleTime);
  }

  if (dwOutputNum != m_dwOutputNum) {
    return S_OK;
  }

  BYTE *pData = NULL;
  DWORD cbData = 0;
  HRESULT hr = pSample->GetBufferAndLength(&pData, &cbData);
  if(FAILED(hr)) {
    return( hr );
  }

  if (m_pOutput) {
    BYTE *pWriteBuf = pData;
    DWORD dwSize = cbData;

    // If we've got to convert from mono to stereo, we need to
    // allocate and copy. The hope is that the per buffer allocation
    // is not too expenseive.
    if (m_bMakeStereo) {
      int sampleSize = (int)(m_wBitsPerSample / 8);
      int numSamples = (int)(cbData/sampleSize);
      dwSize = 2 * cbData;
      BYTE* pDestBuf = pWriteBuf = new BYTE[dwSize];
      BYTE* pSrcBuf = pData;
      for (int i = 0; i < numSamples; i++) {
        for (int j = 0; j < sampleSize; j++) {
          pDestBuf[j] = pSrcBuf[j];
          pDestBuf[j + sampleSize] = pSrcBuf[j];
        }
        pDestBuf += (2 * sampleSize);
        pSrcBuf += sampleSize;
      }
    }

    // Write out samples
    if (!fwrite(pWriteBuf, sizeof(BYTE), dwSize, m_pOutput)) {
      m_hrAsync = -1;
      if (bDebug) {
        fprintf(stderr, "GOT fwrite event!\n");
      }
      SetEvent(m_hEvent);
    } else {
      dwTotalSize += dwSize;
    }
    fflush(m_pOutput);

    // If we allocated before, free now
    if (m_bMakeStereo) {
      delete [] pWriteBuf;
    }
  }

  return S_OK;
}

HRESULT STDMETHODCALLTYPE 
WMAReader::OnStatus(WMT_STATUS Status,
                    HRESULT hr,
                    WMT_ATTR_DATATYPE dwType,
                    BYTE __RPC_FAR *pValue,
                    void __RPC_FAR *pvContext) {
  switch( Status ) {
    case WMT_OPENED:
      m_hrAsync = hr;
      if (bDebug) {
        fprintf(stderr, "GOT WMT_OPENED event!\n");
      }
      SetEvent(m_hEvent);        
      break;
    case WMT_STARTED:
      m_qwReaderTime = ONE_SECOND;
      hr = m_pReaderAdvanced->DeliverTime(m_qwReaderTime);
      if (FAILED(hr)) {
        m_hrAsync = hr;
        if (bDebug) {
       	  fprintf(stderr, "GOT WMT_STARTED / FAILED event!\n");
        }
        SetEvent(m_hEvent);        
      }
      break;
    case WMT_EOF:
      m_hrAsync = hr;
      if (bDebug) {
        fprintf(stderr, "GOT WMT_EOF event!\n");
      }
      SetEvent(m_hEvent);        
      break;
    case WMT_END_OF_STREAMING:
      if (bDebug) {
        fprintf(stderr, "GOT WMT_END_OF_STREAMING event!\n");
      }
      break;
    case WMT_ERROR:
      m_hrAsync = hr;
      if (bDebug) {
        fprintf(stderr, "GOT WMT_ERROR event!\n");
      }
      SetEvent(m_hEvent);        
      break;
  }

  return S_OK;
}

HRESULT STDMETHODCALLTYPE 
WMAReader::OnTime(QWORD cnsCurrentTime,
                  void *pvContext) {
  m_qwReaderTime += ONE_SECOND;
  HRESULT hr = m_pReaderAdvanced->DeliverTime(m_qwReaderTime);
  if (FAILED(hr)) {
    m_hrAsync = hr;
    if (bDebug) {
      fprintf(stderr, "GOT OnTime FAILED event!\n");
    }
    SetEvent(m_hEvent);
  }
  return S_OK;
}

HRESULT
WMAReader::StartReading() {

  // Wait till the open happens
  WaitForSingleObject(m_hEvent, INFINITE);
  if (FAILED(m_hrAsync)) {
    fprintf(stderr, "Opening stream failed with error code 0x%x\n", m_hrAsync);
    return m_hrAsync;
  }

  DWORD dwOutputCount;
  HRESULT hr = m_pReader->GetOutputCount(&dwOutputCount);
  if (FAILED(hr)) {
    fprintf(stderr, "Getting output count failed with error code 0x%x\n", hr);
    return hr;
  }

  for (DWORD i = 0; i < dwOutputCount, m_dwOutputNum == -1; i++) {
    IWMOutputMediaProps* pProps;
    hr = m_pReader->GetOutputProps(i, &pProps);
    if (FAILED(hr)) {
      fprintf(stderr, "Getting output props failed with error code 0x%x\n", 
              hr);
      return hr;
    }

    GUID guidType;
    hr = pProps->GetType(&guidType);
    if (SUCCEEDED(hr)) {
      if (guidType == WMMEDIATYPE_Audio) {
        m_dwOutputNum = i;
      }  
    }
    else {
      fprintf(stderr, "Getting output type failed with error code 0x%x\n", 
              hr);
    }

    pProps->Release();
    if (FAILED(hr)) {
      return hr;
    }
  } 

  if (m_dwOutputNum == -1) {
      fprintf(stderr, "Couldn't find an audio track in file\n");
      return E_INVALIDARG;
  }

  DWORD dwFormatCount;
  hr = m_pReader->GetOutputFormatCount(m_dwOutputNum, &dwFormatCount);
  if (FAILED(hr)) {
    fprintf(stderr, "Getting output format count failed "
            "with error code 0x%x\n", hr);
    return hr;
  }

  BOOL bFoundMatch = FALSE;
  for (DWORD i = 0; i < dwFormatCount; i++) {
    IWMOutputMediaProps* pOutputProps;
    hr = m_pReader->GetOutputFormat(m_dwOutputNum, i, &pOutputProps);
    if (FAILED(hr)) {
      fprintf(stderr, "Getting format output props failed "
              "with error code 0x%x\n", hr);
      break;
    }
          
    WM_MEDIA_TYPE* pMediaType = NULL;
    do {
      ULONG cbType;
      hr = pOutputProps->GetMediaType(NULL, &cbType);
      if (FAILED(hr)) {
        fprintf(stderr, "Getting media type struct size failed "
                "with error code 0x%x\n", hr);
        break;
      }
      
      pMediaType = (WM_MEDIA_TYPE*)new BYTE[cbType];
      hr = pOutputProps->GetMediaType(pMediaType, &cbType);
      if (FAILED(hr)) {
        fprintf(stderr, "Getting media type struct failed "
                "with error code 0x%x\n", hr);
        break;
      }

      if (pMediaType->formattype == WMFORMAT_WaveFormatEx) {
        WAVEFORMATEX* pFormat = (WAVEFORMATEX*)pMediaType->pbFormat;

        if ((pFormat->wFormatTag == WAVE_FORMAT_PCM) &&
            (pFormat->nSamplesPerSec == m_dwSamplesPerSec) &&
            (pFormat->wBitsPerSample == m_wBitsPerSample)) {
          if ((pFormat->nChannels == m_dwNumChannels) ||
              !bFoundMatch) {
            bFoundMatch = TRUE;
            hr = m_pReader->SetOutputProps(m_dwOutputNum, pOutputProps);
            if (FAILED(hr)) {
              fprintf(stderr, "Setting audio output properties failed "
                      "with error code 0x%x\n", hr);
              break;
            }
            if (pFormat->nChannels == 1 &&
                m_dwNumChannels == 2) {
              m_bMakeStereo = TRUE;
            }
            else {
              m_bMakeStereo = FALSE;
            }
          }
        }
      }
    } while (FALSE);

    if (pMediaType) {
      delete [] pMediaType;
    }

    pOutputProps->Release();
    if (FAILED(hr)) {
      break;
    }
  } 

  if (FAILED(hr)) {
    return hr;
  }

  if (!bFoundMatch) {
    fprintf(stderr, "Can't find reader that matches the specified "
            "audio output properties\n");
    return E_INVALIDARG;
  }

  m_pReaderAdvanced->SetUserProvidedClock(TRUE);

  hr = m_pReader->Start(0, 0, 1.0, NULL);
  if (FAILED(hr)) {
    fprintf(stderr, "Attempt to start reading failed "
            "with error code 0x%x\n", hr);
    return hr;
  }

  WaitForSingleObject(m_hEvent, INFINITE);
  if (FAILED(m_hrAsync)) {
    fprintf(stderr, "Reading from stream failed with error code 0x%x\n", 
            m_hrAsync);
    return m_hrAsync;
  }

  m_pReader->Close();

  return S_OK;
}

HRESULT
WMAReader::Decode(LPCSTR lpInput, FILE* pOutput) {
  HRESULT hr = Init(pOutput);
  if (FAILED(hr)) {
    return hr;
  }

  int length = (int)strlen(lpInput);
  int count = MultiByteToWideChar(CP_ACP, 0, lpInput, length, NULL, 0);
  LPWSTR pwszURL = new WCHAR[count + 1];
  MultiByteToWideChar(CP_ACP, 0, lpInput, length, pwszURL, count);
  pwszURL[count] = (WCHAR)0;

  hr = m_pReader->Open(pwszURL, this, NULL);
  if (SUCCEEDED(hr)) {
    hr = StartReading();
  }
  else {
    fprintf(stderr, "Error opening file for reading: 0x%x\n", hr);
  }
                  
  delete [] pwszURL;

  return hr;
}

HRESULT
WMAReader::Decode(IStream* lpInput, FILE* pOutput) {
  HRESULT hr = Init(pOutput);
  if (FAILED(hr)) {
    return hr;
  }
  
  IWMReaderAdvanced2 *pAdvanced2 = NULL;
  hr = m_pReader->QueryInterface(IID_IWMReaderAdvanced2, 
                                 (void**)&pAdvanced2);
  if (FAILED(hr)) {
    fprintf(stderr, "Error QIing WMA reader 0x%x\n", hr);
    return hr;
  }
  pAdvanced2->SetPlayMode(WMT_PLAY_MODE_STREAMING);

  hr = pAdvanced2->OpenStream(lpInput, this, NULL);
  if (SUCCEEDED(hr)) {
    hr = StartReading();
  }
  else {
    fprintf(stderr, "Error opening stream for reading: 0x%x\n", hr);
  }

  pAdvanced2->Release();
  return hr;
}

void
printUsage() {
  fprintf(stderr, 
          "wmadec [-dqhw] [ -b bits_per_sample ] [ -r sample_rate ]\n"
          "[ -n num_channels ] [ -o outputfile ] [input]\n"
          "-d\n"
          "\tAdd debugging output.\n"
          "-q\n"
          "\tSuppresses program output.\n"
          "-h\n"
          "\tPrint help message.\n"
          "-b n\n"
          "\tBits per sample of output.  Valid values are 8 or 16 (default)\n"
          "-r n\n"
          "\tSample rate of output. Default is 44100.\n"
          "-n n\n"
          "\tNumber of channels of output. Default is 2\n"
          "-o filename\n"
          "\tWrite output to specified filename.  Default is stdout.\n"
          "-w\n"
          "\tAdd wave headers\n"
          "-l bytes\n"
          "\tlength of decoded output in bytes");
}

// Superlexx: Write*Bits* and WriteWaveHeader are taken from LAME
void
Write16BitsLowHigh(FILE *fp, int i)
{
	putc(i&0xff,fp);
	putc((i>>8)&0xff,fp);
}

// Superlexx: Write32Bits* and WriteWaveHeader are taken from LAME
void
Write32BitsLowHigh(FILE *fp, int i)
{
	Write16BitsLowHigh(fp,(int)(i&0xffffL));
	Write16BitsLowHigh(fp,(int)((i>>16)&0xffffL));
}

// Superlexx: this function is slightly modified (pcmbytes is a parameter now)
int WriteWaveHeader(FILE * const fp, 
	const int freq, const int channels, const int bits, DWORD pcmbytes)
{
	int bytes = (bits + 7) / 8;

	/* quick and dirty, but documented */
	fwrite("RIFF", 1, 4, fp); /* label */
	Write32BitsLowHigh(fp, pcmbytes + 44 - 8); /* length in bytes without header */
	fwrite("WAVEfmt ", 2, 4, fp); /* 2 labels */
	Write32BitsLowHigh(fp, 2 + 2 + 4 + 4 + 2 + 2); /* length of PCM format declaration area */
	Write16BitsLowHigh(fp, 1); /* is PCM? */
	Write16BitsLowHigh(fp, channels); /* number of channels */
	Write32BitsLowHigh(fp, freq); /* sample frequency in [Hz] */
	Write32BitsLowHigh(fp, freq * channels * bytes); /* bytes per second */
	Write16BitsLowHigh(fp, channels * bytes); /* bytes per sample time */
	Write16BitsLowHigh(fp, bits); /* bits per sample */
	fwrite("data", 1, 4, fp); /* label */
	Write32BitsLowHigh(fp, pcmbytes); /* length in bytes of raw PCM data */

	return ferror(fp) ? -1 : 0;
}

int _tmain(int argc, _TCHAR* argv[])
{
  BOOL bQuiet = FALSE;
  WORD wBitsPerSample = 16;
  DWORD dwSamplesPerSec = 44100;
  DWORD dwNumChannels = 2;
  LPCSTR pOutputFile = NULL;
  FILE* pOutputHandle = stdout;
  BOOL bUsage = FALSE;
  BOOL bWaveHeaders = FALSE;
  DWORD dwPCMBytes = 0xFFFFFFFF;

  char c;
  while ((c = getopt(argc, argv, gOptionStr)) != EOF) {
    switch(c) {
      case 'd':
        bDebug = TRUE;
        break;
      case 'q':
        bQuiet = TRUE;
        break;
      case 'h':
      case 'v':
        bUsage = TRUE;
        break;
      case 'b':
        wBitsPerSample = atoi(optarg);
        if (wBitsPerSample != 8 && wBitsPerSample != 16) {
          fprintf(stderr, 
                  "Illegal value passed for bits per sample parameter\n");
          bUsage = TRUE;
        }
        break;
      case 'r':
        dwSamplesPerSec = atoi(optarg);
        if (dwSamplesPerSec <= 0) {
          fprintf(stderr, 
                  "Illegal value passed for sample rate parameter\n");
          bUsage = TRUE;
        }
        break;
      case 'n':
        dwNumChannels = atoi(optarg);
        if (dwNumChannels <= 0) {
          fprintf(stderr, 
                  "Illegal value passed for number of channels parameter\n");
          bUsage = TRUE;
        }
        break;
      case 'o': 
        pOutputFile = optarg;
        break;
      case 'w':
	bWaveHeaders = TRUE;
	break;
      case 'l':
	dwPCMBytes = atoi(optarg);
	break;
      case '\0': 
        bUsage = TRUE;
    }
  }

  if (bUsage) {
    printUsage();
    exit(1);
  }

  errno_t err;

  if (bQuiet) {
    pOutputHandle = NULL;
  }
  // Open the output file if one is specified.
  else if (pOutputFile) {
    if ((err = fopen_s(&pOutputHandle, pOutputFile, "w+b")) != 0) {
      fprintf(stderr, "Error opening file %s for writing\n", pOutputFile);
    }
  }
  else {
    _setmode(_fileno(stdout), O_BINARY);  
    pOutputHandle = stdout;
  }

  if (bWaveHeaders) {
    WriteWaveHeader(pOutputHandle, dwSamplesPerSec, dwNumChannels, wBitsPerSample, dwPCMBytes);
  }

  WMAReader* pReader = new WMAReader(wBitsPerSample,
                                     dwSamplesPerSec,
                                     dwNumChannels);
  pReader->AddRef();
  if ((optind < argc) && (strcmp(argv[optind], "-") != 0)) {
    pReader->Decode(argv[optind], pOutputHandle);
  }
  else {
    _setmode(_fileno(stdin), O_BINARY);   
    WMAStream* pStream = new WMAStream(stdin);
    pStream->AddRef();
    pReader->Decode(pStream, pOutputHandle);    
    pStream->Release();
  }
  pReader->Release();
  if (pOutputHandle && pOutputFile) {
    fclose(pOutputHandle);
  }

  if (bDebug) {
    fprintf(stderr, "dwTotalSize: [%d]\n", dwTotalSize);
  }
  
  return 0;
}
