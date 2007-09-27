/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: 4; c-basic-offset: 4 -*- */
//
// SqueezeCenter Copyright (C) 2003-2004 Vidur Apparao, Slim Devices Inc.
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License,
// version 2.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//

// This utility is used on Windows to enable non-blocking bidirectional IPC from Perl.
// Since IPC::Open3 doesn't allow non-blocking IPC (since it uses Pipes), this utility
// can be used to set up sockets (which can be put into non-blocking mode) to 
// communicate with a helper application.
// The utility is invoked with input and output port numbers that represent localhost
// ports that can be connected to for IPC. After connecting to the ports, the utility
// invokes the downstream helper application, substituting the two ports for stdin and
// stdout.
// 
// ++++++
// Version 1.1
// Updated to allow the 1st command in a pipeline to write to a file instead of stdout
// To use this option include the string PIPE_TOKEN in the first command and it will get
// replaced by a windows named pipe when this command is executed
// e.g. command1 arg11 arg12 arg13 #PIPE# arg14 | command2 arg21 arg22 ...
//      will execute command1 arg1 arg2 arg3 \\\\.\\pipe\\<pipename> arg4
//           &       command2 arg21 arg22
// 
// A second thread at higher priority is created to move data from the Named Pipe to the
// second process/output.  The main thread monitors its progress and kills it if no 
// data is moved within the period TIMEOUT.
// To debug this mode use the alternative token DEBUG_PIPE_TOKEN (#DEBUGPIPE#) - depreciated
// Caveat: This mode will only work on Windows versions supporting CreateNamedPipe: NT/2K/XP/2003
//
// ++++++
// Version 1.2/1.3 - Ian Cook, Bryan Alton
// Completely updated to avoid passing socket handles between processes. Whatever method 
// was tried to do this, it was broken by various 3rd party software 
// (e.g. VPN clients/firewalls etc)
//
// The new approach is to use pipes to communicate with all child processes and use
// additional worker threads in socketwrapper to transfer data between the pipes and the 
// sockets (which are now all local to the socketwrapper process itself)
// 
// ++++++
// Version 1.4
// Modified debugging to be triggered by -d | -D command line option for better integration with server
//
// ++++++
// Version 1.5
// First attempt at solving truncation issue.
//
// ++++++
// Version 1.6
// Added changes to close pipe at main level and flush buffers to avoid truncation.
//
// ++++++
// Version 1.7
// Made watchog optional because of problem with paused files. 
// Watchdog is enabled by -w .  This is needed for use with streaming audio such as AlienBBC
// in case stream stops and socketwrapper thread hangs on a read.
//
// ++++++
// Version 1.8
// Fix Lame truncation problem.
//
// ++++++
// Version 1.9
// Fix occasional crashes when closing down. bug #5128
//
// ++++++
// Version 1.10
// Fix thread CPU hog when input stream is closed - when EOF detected close thread. bug #5164


#include <process.h>
#include "stdafx.h"
#include "getopt.h"

#define	 SW_ID			  "Socketwrapper 1.10\n"

// defines & global vars for extra thread mode
#define  MAX_STEPS        16
#define  PIPE_TOKEN       "#PIPE#"                     // token to look for
#define  PIPE_NAME_ROOT   "\\\\.\\pipe\\socketwrapper" // root of named pipe name
#define  BUFFER_SIZE      8192                         // size of buffer for transfers & named pipe
#define  TIMEOUT          60000                        // timeout for wait checking thread state
#define  DEBUG_TIMEOUT    10000                        // timeout when in debug mode

// info about each step in process (also used as context for thread creation)
typedef struct
{
	int i;
	bool fIsWorkerThread;	// true for thread, false for child process
	bool fInputIsNamed;		// for thread, true if input handle is named pipe false otherwise
	bool fOutputIsSocket;   // true for last thread sending output to a socket
	char *pBuff;			// either transfer buffer for thread or cmdline for process
	HANDLE hInput;			// input handle for process/thread
	HANDLE hOutput;			// output handle for process/thread
	DWORD WatchDog;			// watchdog for worker threads
	DWORD nBlocks;			// number of "blocks" read
	DWORD nBytes;			// number of bytes read
} Stage;

BOOL bWatchdogEnabled = FALSE;
BOOL bDebug = FALSE;
BOOL bDebugVerbose = FALSE;

void
printUsage() {
	fprintf(stderr,
		SW_ID
		"Usage: socketwrapper -i port -o port [-d | -D] -c command\n"
		"-o port \tUnix domain port to connect to for output.\n"
		"-i port \tUnix domain port to connect to for input.\n"
		"-c command \tCommand to execute.\n"
		"-w \t\tEnables watchdog.\n"
		"-d \t\tEnable debugging ouput.\n"
		"-D \t\tEnable Verbose debugging ouput.\n"
	);
}

#define STRINGLEN 512
#define STAMPEDMSGLEN (STRINGLEN+32)
void 
stderrMsg ( const char *fmt, ...) {
	    SYSTEMTIME st;
		va_list ap;
		char str[STRINGLEN];
		char stampedmsg[STAMPEDMSGLEN];

		GetLocalTime(&st);

		va_start(ap,fmt);
		vsnprintf_s(str,STRINGLEN,_TRUNCATE, fmt, ap);
		va_end(ap);

		_snprintf_s(stampedmsg,STAMPEDMSGLEN,_TRUNCATE, "SW: %4d-%02d-%02d %2d:%02d:%02d.%03d %s", 
                   st.wYear, st.wMonth,  st.wDay, st.wHour, 
                   st.wMinute, st.wSecond, st.wMilliseconds,str);

        fputs(stampedmsg,stderr);
		fflush(stderr);
}

void 
debugMsg ( const char *fmt, ...) {
    SYSTEMTIME st;
	va_list ap;

	char str[STRINGLEN];
	char stampedmsg[STAMPEDMSGLEN];

	if (bDebug){
        GetLocalTime(&st);

        va_start(ap,fmt);
		vsnprintf_s(str,STRINGLEN,_TRUNCATE, fmt, ap);
		va_end(ap);

		_snprintf_s(stampedmsg,STAMPEDMSGLEN,_TRUNCATE, "SW: %4d-%02d-%02d %2d:%02d:%02d.%03d %s", 
                   st.wYear, st.wMonth,  st.wDay, st.wHour, 
                   st.wMinute, st.wSecond, st.wMilliseconds,str);

        fputs(stampedmsg,stderr);
		fflush(stderr);

	}
}

//
// MoveDataThreadProc
//
// this is used for transferring data (when appropriate) as follows
//	* from the named pipe to the next process (the original use of an extra thread)
//  * from the input socket via a pipe to the first process
//	* from the last process via a pipe to the output socket
//
unsigned __stdcall MoveDataThreadProc(void *pv) 
{
	Stage *pS = (Stage *)pv;
	bool fShowDebug = true;
	DWORD nNummsgs = 0;

	debugMsg ( "MoveDataThreadProc for step %i started.\n", pS->i );

	// if the input handle is for a named pipe then wait for the other end
	if( pS->fInputIsNamed ){

		if( !ConnectNamedPipe( pS->hInput, NULL) ) {
			stderrMsg ( "MoveDataThreadProc for step %i failed to attach to named pipe.\n", pS->i );
			_endthreadex(1); 
			return 1;
		} 

		debugMsg ( "MoveDataThreadProc for step %i attached to named pipe.\n", pS->i );
	}

	DWORD bytesread, byteswritten;

	for(;;)	{

		if( fShowDebug ) {
			debugMsg ( "MoveDataThreadProc for step %i about to call ReadFile.\n", pS->i );
		}

		// wait for some data from input
		if( !ReadFile(pS->hInput, pS->pBuff, BUFFER_SIZE, &bytesread, NULL) ) {
			stderrMsg ( "MoveDataThreadProc for step %i failed reading with error %i.\n", pS->i, GetLastError() );
			break;
		}
		if (bytesread == 0) {
			DWORD lasterror = GetLastError();
			stderrMsg ( "MoveDataThreadProc for step %i read returned 0 bytes with no error. Last Error = %i.\n", pS->i, lasterror );
			if (lasterror != 0) break;
		// So no error and 0 bytes this means EOF so terminate the thread. 
			break;

		}


		pS->nBytes += bytesread;
		pS->nBlocks++;

		// log when data starts
		if( fShowDebug ) {
			debugMsg ( "MoveDataThreadProc for step %i got %i bytes, about to write data.\n", pS->i, bytesread );
			nNummsgs++;
		}

		// pass data to output
		if (!pS->fOutputIsSocket){
			if( !WriteFile(pS->hOutput, pS->pBuff, bytesread, &byteswritten, NULL) ) {
				stderrMsg ( "MoveDataThreadProc for step %i failed WriteFile with error %i.\n", pS->i, GetLastError() );
				break;
			}
		} else {
			byteswritten = send ((SOCKET) pS->hOutput, pS->pBuff, bytesread, 0 );
			if (byteswritten == INVALID_SOCKET) {
				stderrMsg ( "MoveDataThreadProc for step %i failed Send writing with error %i.\n", pS->i, WSAGetLastError());
				break;
			}
			if (byteswritten != bytesread) {
				stderrMsg ( "MoveDataThreadProc for step %i : bytesread=%i byteswritten=%i\n", pS->i, bytesread, byteswritten );
				break;
			}
		}

		// increase watchdog counter
		++(pS->WatchDog);

		// turn off debug once going and verbose debug is not set
		if (nNummsgs > 1 && !bDebugVerbose) fShowDebug = false;
	}


	debugMsg ( "MoveDataThreadProc for step %i ending.\n", pS->i );
	if (!pS->fOutputIsSocket) {
		if (!FlushFileBuffers(pS->hOutput)) {
			stderrMsg ( "Error Flushing Output in Thread for step %d: %d\n", pS->i, GetLastError());
		} 
	} else {
		shutdown((SOCKET) pS->hOutput, SD_SEND);
	}
	if(!CloseHandle(pS->hOutput )) {
		stderrMsg ( "CloseHandle for step %i failed with error %i.\n", pS->i, GetLastError() );
	}
 
	_endthreadex(0); 
	return 0;
}



DWORD main(int argc, char **argv)
{
	USHORT inputPort = 0, outputPort = 0;
	SOCKET inputSocket = INVALID_SOCKET, outputSocket = INVALID_SOCKET;
	LPSTR command = NULL;
	DWORD ret = 0;
	
	// Parse the command line arguments
	char c;
	while ((c = getopt(argc, argv, "i:o:c:wdD")) != EOF) {
		switch(c) {
			case 'i':
				inputPort = atoi(optarg);
				break;
			case 'o':
				outputPort = atoi(optarg);
				break;
			case 'c':
				command = optarg;
				break;
			case 'w':
				bWatchdogEnabled = true;
				break;
			case 'd':
				bDebug = true;
				break;
			case 'D':
				bDebug = true;
				bDebugVerbose = true;
				break;
			case '\0':
				printUsage();
				return -1;
		}
	}

	debugMsg ( SW_ID );

	if (!command) {
		printUsage();
		return -1;
	}

	debugMsg( "-i %i -o %i -c %s\n", inputPort, outputPort, command );

	// Initialize Winsock
	WORD wVersionRequested = MAKEWORD( 1, 1 );
	WSADATA wsaData;
	int err = WSAStartup( wVersionRequested, &wsaData );
	if ( err != 0 ) {
		stderrMsg( " Couldn't initialize winsock\n");
		return -1;
	}

	// reset our arrays
	int numSteps = 0;

	Stage info[MAX_STEPS] = {0};
	HANDLE hChild[MAX_STEPS] = {0};

	// count processes to spawn
	int numProcesses = 0;
	LPSTR token = strtok(command, "|");
	while (token) {
		numProcesses++;
		token = strtok(NULL, "|");
	}

	// input socket - use via unnamed pipe and worker thread
	if( inputPort )
	{
		debugMsg ( "Input from socket ...\n");
		struct sockaddr_in addr;
		addr.sin_family = AF_INET;
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

		inputSocket = WSASocket(AF_INET, SOCK_STREAM, 0, NULL, 0, 0);
		if (inputSocket == INVALID_SOCKET) {
			stderrMsg( " Input socket creation error: %d\n", WSAGetLastError());
			ret = -1;
			goto tidy;
		}

		int iMode = 0;
		ioctlsocket(inputSocket, FIONBIO, (u_long FAR*) &iMode);

		addr.sin_port = htons(inputPort);
		if (connect(inputSocket, (const sockaddr*)&addr, sizeof(addr)) == SOCKET_ERROR) {
			stderrMsg( " input socket connection error: %d\n", WSAGetLastError());
			ret = -1;
			goto tidy;
		}

		debugMsg ( "Input socket connected OK.\n");

		info[numSteps].hInput = (HANDLE)inputSocket;
		info[numSteps].fIsWorkerThread = true;
		info[numSteps].fInputIsNamed = false;
		info[numSteps].fOutputIsSocket = false;
		
		SECURITY_ATTRIBUTES saAttr; 
		saAttr.nLength = sizeof(SECURITY_ATTRIBUTES); 
		saAttr.bInheritHandle = TRUE; 
		saAttr.lpSecurityDescriptor = NULL; 
		
		if (!CreatePipe(&(info[numSteps+1].hInput),
						&(info[numSteps].hOutput), 
						&saAttr, 0)){
			stderrMsg ( "Input socket pipe creation error: %d\n", GetLastError());
			ret = -1;
			goto tidy;
		}

		debugMsg ( "Input socket pipe created OK.\n");
		++numSteps;
	}
	else{
		info[numSteps].hInput = GetStdHandle(STD_INPUT_HANDLE);
	}

	// command line
	token = command;
	for (int i = 0; i < numProcesses; i++) 
	{
		while( *token==' ' ) ++token;

		LPSTR p = strstr(token, PIPE_TOKEN);

		if (p != NULL) // PIPE_TOKEN found
		{
			LPSTR p2 = p;
			char pszNP[sizeof(PIPE_NAME_ROOT)+8];
			sprintf( pszNP, "%s%06d", PIPE_NAME_ROOT, getpid() );
			size_t n = strlen(token)+strlen(PIPE_NAME_ROOT)+8;
			info[numSteps].pBuff = (char *)malloc(n);
			if( info[numSteps].pBuff == NULL) {
				stderrMsg ( "pBuff malloc failed\n");
				ret = -1;
				goto tidy;
			}

			p = p+strlen( PIPE_TOKEN );
			*p2='\0';
			sprintf((char *)info[numSteps].pBuff, "%s%s%s", token, pszNP, p); 
			*p2='#';
			info[numSteps+1].hInput = CreateNamedPipe( pszNP,
							PIPE_ACCESS_INBOUND,
							PIPE_TYPE_BYTE|PIPE_WAIT,
							1,
							BUFFER_SIZE,
							BUFFER_SIZE,
							INFINITE,
							NULL);
			if(info[numSteps+1].hInput == INVALID_HANDLE_VALUE) {
				stderrMsg ( "Error Creating Named Pipe: %d\n", GetLastError());
				ret = -1;
				goto tidy;
			}
			info[numSteps].hOutput = GetStdHandle(STD_ERROR_HANDLE);
			++numSteps;

			info[numSteps].fIsWorkerThread = true;
			info[numSteps].fInputIsNamed = true;
			info[numSteps].fOutputIsSocket = false;

		} else {  // no PIPE_TOKEN
			info[numSteps].pBuff = (char *)malloc(strlen(token)+1);
			if( info[numSteps].pBuff == NULL) {
				stderrMsg ( "malloc failed\n");
				ret = -1;
				goto tidy;
			}
			strcpy( (char *)info[numSteps].pBuff, token );
		}

		if ( i != numProcesses - 1 || outputPort ) {

			SECURITY_ATTRIBUTES saAttr; 
			saAttr.nLength = sizeof(SECURITY_ATTRIBUTES); 
			saAttr.bInheritHandle = TRUE; 
			saAttr.lpSecurityDescriptor = NULL; 
			
			if (!CreatePipe(&(info[numSteps+1].hInput),
							&(info[numSteps].hOutput), 
							&saAttr, 0)){
				stderrMsg ( "Error Creating Pipe: %d\n", GetLastError());
				ret = -1;
				goto tidy;
			}
		}

		// last process
		if ( i == numProcesses - 1 ) {

			if ( outputPort ){
				// anon pipe already done
				// open socket
				++numSteps;
				info[numSteps].fIsWorkerThread = true;
				info[numSteps].fInputIsNamed = false;
				info[numSteps].fOutputIsSocket = true;

				outputSocket = WSASocket(AF_INET, SOCK_STREAM, 0, NULL, 0, 0);
				if (outputSocket == INVALID_SOCKET) {
					stderrMsg ( "Error creating output socket: %d\n", WSAGetLastError());
					ret = -1;
					goto tidy;
				}
				int iMode = 0;
				ioctlsocket(outputSocket, FIONBIO, (u_long FAR*) &iMode);

				struct sockaddr_in addr;
				addr.sin_family = AF_INET;
				addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
				addr.sin_port = htons(outputPort);
				if (connect(outputSocket, (const sockaddr*)&addr, 
							sizeof(addr)) == SOCKET_ERROR) {
					stderrMsg ( "Error connecting to output socket: %d\n", WSAGetLastError());
					ret = -1;
					goto tidy;
				}
				info[numSteps].hOutput = (HANDLE)outputSocket;
			}
			else{
				info[numSteps].hOutput = GetStdHandle(STD_OUTPUT_HANDLE);
			}
		}

		++numSteps;

		token += strlen(token) + 1;
	}

	// debugging
	debugMsg ( "Init complete.\n" );
	debugMsg ( "# =input== =output= ==type== ===details===\n" );
	for( int i=0; i<numSteps; ++i ){
		info[i].i = i;
		if( info[i].fIsWorkerThread )
			debugMsg ( "%1x %08x %08x  THREAD  %s%s\n", i, info[i].hInput, info[i].hOutput, (info[i].fInputIsNamed ? "Named Pipe" : ""), (info[i].fOutputIsSocket ? "Output Socket" : ""));
		else
			debugMsg ( "%1x %08x %08x  PROCESS %s\n" ,i, info[i].hInput, info[i].hOutput, info[i].pBuff );
	}
	
	// turn on the pumps
	for( int i = 0; i < numSteps; ++i ){
		if( info[i].fIsWorkerThread )
		{
			info[i].pBuff = (char *)malloc(BUFFER_SIZE);
			if( info[i].pBuff == NULL) {
				stderrMsg ( "malloc failed for step %d \n",i);
				ret = -1;
				goto tidy;
			}

			hChild[i] = (HANDLE)_beginthreadex(NULL, 0, &MoveDataThreadProc, &info[i], 0, NULL);
			if( hChild[i] ) 
			{
				if (!SetThreadPriority( hChild[i], THREAD_PRIORITY_TIME_CRITICAL)) {
					stderrMsg ( "Error changing thread priority for step %d : %d\n",i, GetLastError());
					ret = -1;
					goto tidy;
				}

			}
		}
	}

	// and turn on the taps
	for( int i = 0; i < numSteps; ++i ){
		if( !info[i].fIsWorkerThread )
		{
			STARTUPINFO siStartInfo;
			PROCESS_INFORMATION piProcInfo; 
	
			ZeroMemory(&piProcInfo, sizeof(PROCESS_INFORMATION));
			ZeroMemory(&siStartInfo, sizeof(STARTUPINFO));

			siStartInfo.cb = sizeof(STARTUPINFO); 

			siStartInfo.hStdError = GetStdHandle(STD_ERROR_HANDLE);
			siStartInfo.hStdInput = info[i].hInput;
			siStartInfo.hStdOutput = info[i].hOutput;
			siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

			if( !CreateProcess(NULL, info[i].pBuff,
								  NULL, // process security attributes 
								  NULL, // primary thread security attributes 
								  TRUE, // handles are inherited 
								  0,    // creation flags 
								  NULL, // use parent's environment 
								  NULL, // use parent's current directory 
								  &siStartInfo,  // STARTUPINFO pointer 
								  &piProcInfo)) {  // receives PROCESS_INFORMATION 
				stderrMsg ( "Error Creating Process for step %d: %d\n", i, GetLastError());
				ret = -1;
				goto tidy;
			}
		
			hChild[i] = piProcInfo.hProcess;
			CloseHandle( piProcInfo.hThread );
			if (info[i].hOutput != GetStdHandle(STD_ERROR_HANDLE))
				CloseHandle(info[i].hOutput);
		}
	}

	bool fDie = false;
	DWORD deadstep = -1;

	while( !fDie )	{
		DWORD wr = WaitForMultipleObjects( numSteps, hChild, FALSE, bDebug ? DEBUG_TIMEOUT : TIMEOUT );
		if( wr!=WAIT_TIMEOUT ) {
			deadstep = wr-WAIT_OBJECT_0;
			stderrMsg( "Timeout Process/Thread for step %i died.\n", deadstep );
			fDie = true;
		}
		for( int i=0; i<numSteps; ++i ){
			if( info[i].fIsWorkerThread ){
				if( 0==info[i].WatchDog ) {
					stderrMsg( "Watchdog expired - Thread for step %i stalled.\n", i );
					if (bWatchdogEnabled)	fDie = true;
				}
				info[i].WatchDog=0;
			}
		}
	}

tidy:
	DWORD wr;

	debugMsg ( "Tidying up \n"); 
	if (deadstep == 0) {
		debugMsg ( " Normal source all read: Process 0 ended \n" );
	} else {
		if (deadstep != -1) debugMsg ( " Process/thread %d stopped\n", deadstep );
		if (fDie) debugMsg ( "Watchdog expired \n"); 
	}
	for( int i = 0; i < numSteps; ++i ){
		if( info[i].fIsWorkerThread ){
				if (bWatchdogEnabled)
					wr = WaitForSingleObject( hChild[i],2000 );
				else 
					wr = WaitForSingleObject( hChild[i],INFINITE );

				if( wr==WAIT_TIMEOUT ) {
					stderrMsg( "Tidying up - Thread for step %d hasn't died.\n", i );
				} else if( wr==WAIT_FAILED ) {
					stderrMsg ( "Tidying up - Wait for thread to die failed for step  %d: %d\n", i, GetLastError());
				}
				debugMsg("Thread for step %i streamed %6i blocks totalling %08X (%d) bytes\n",i, info[i].nBlocks , info[i].nBytes, info[i].nBytes );
			} else {
			debugMsg("Waiting for process step %i to terminate\n",i);
			wr = WaitForSingleObject( hChild[i], 2000 );
			if( wr==WAIT_TIMEOUT || wr==WAIT_FAILED ) {
				stderrMsg( "Tidying up - process for step %d hasn't died or wait failed. wr=%d :%d \n", i,wr, GetLastError() );
				if( hChild[i] ) {
					if (!TerminateProcess( hChild[i], 0 ) )
						stderrMsg ( "Error Terminating Process for step %d: %d\n", i, GetLastError());
				}
			}
		}
		if( info[i].pBuff ) free( info[i].pBuff );
	}

//
//  Now that all processes are terminated - check if any threads are still running and end them as well.
//

	for( int i = 0; i < numSteps; ++i ){
		if( info[i].fIsWorkerThread ){
			DWORD threadExitCode;
			if (GetExitCodeThread(hChild[i],&threadExitCode)) {
				if (threadExitCode == STILL_ACTIVE){
					debugMsg("Exitcode for Thread %i Code=%d\n",i,threadExitCode);
					if(!TerminateThread(hChild[i], 2)) {
						stderrMsg ( "Error trying to TerminateThread for step %d: %d\n", i, GetLastError());
					}
				}
			} else {
				stderrMsg ( "Error GetExitThreadCode for step %d: %d\n", i, GetLastError());
			}
			CloseHandle(hChild[i]); // CloseHandle is required because _beginthreadex was used.
		}
	}

	if( outputSocket ) closesocket( outputSocket );
	if( inputSocket )  closesocket( inputSocket );
	FlushFileBuffers(GetStdHandle(STD_OUTPUT_HANDLE));
	debugMsg("Socketwrapper has terminated.\n\n");
	return 0;
}
