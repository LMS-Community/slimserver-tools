/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: 4; c-basic-offset: 4 -*- */
//
// SlimServer Copyright (C) 2003-2004 Vidur Apparao, Slim Devices Inc.
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
// To debug this mode use the alternative token DEBUG_PIPE_TOKEN (#DEBUGPIPE#)
// Caveat: This mode will only work on Windows versions supporting CreateNamedPipe: NT/2K/XP/2003

#include <process.h>
#include "stdafx.h"
#include "getopt.h"

// defines & global vars for NPIPE mode
#define  PIPE_TOKEN       "#PIPE#"                     // token to look for
#define  DEBUG_PIPE_TOKEN "#DEBUGPIPE#"                // alternative token - debug enabled 
#define  PIPE_NAME_ROOT   "\\\\.\\pipe\\socketwrapper" // root of named pipe name
#define  BUFFER_SIZE      4096                         // size of buffer for transfers & named pipe
#define  TIMEOUT          60000                        // timeout for wait checking thread state
#define  DEBUG_TIMEOUT    10000                        // timeout when in debug mode

HANDLE hRWReader = INVALID_HANDLE_VALUE, hRWWriter = INVALID_HANDLE_VALUE;
UINT   watchDogCount = 1;
BOOL   bDebug = FALSE;

static char* gOptionStr = "i:o:c:";

void
KillAllProcesses(PHANDLE pProcessHandles, int numProcesses) {
	for (int i = 0; i < numProcesses; i++) {
		if (pProcessHandles[i] == INVALID_HANDLE_VALUE) {
			break;
		}
		TerminateProcess(pProcessHandles[i], 0);
		CloseHandle(pProcessHandles[i]);
	}
}

void
printUsage() {
	fprintf(stderr, 
	  "socketwrapper -i port -o port -c command\n"
	  "-o port\n"
	  "\tUnix domain port to connect to for output.\n"
	  "-i port\n"
	  "\tUnix domain port to connect to for input.\n"
	  "-c command\n"
	  "\tCommand to execute.\n");
}

unsigned __stdcall
MoveData(void *buff) {
	// Called as a new thread to move data between NPIPE and second command
	if (!ConnectNamedPipe(hRWReader, NULL)) {
		if (bDebug)
			fprintf(stderr, "SW: Failed Connect to Named Pipe\n"); 
		_endthreadex(1); 
		return 1;
	} 
	DWORD bytesread, byteswritten;
	while (ReadFile(hRWReader, buff, BUFFER_SIZE, &bytesread, NULL)){
		if (!WriteFile(hRWWriter, buff, bytesread, &byteswritten, NULL)) 
			break;
		watchDogCount++;  // main thread monitors this
		if (bDebug)
			fprintf(stderr, "SW: Transfering: %u\r", watchDogCount);
	}
	if (bDebug)
		fprintf(stderr, "SW: Transfering complete          \n");
	_endthreadex(0); 
	return 0;
}

DWORD main(int argc, char **argv) 
{
	USHORT inputPort = 0, outputPort = 0;
	LPSTR command = NULL;

	// Parse the command line arguments
	char c;
	while ((c = getopt(argc, argv, gOptionStr)) != EOF) {
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
			case '\0':
				printUsage();
				return -1;
		}
	}

	if (!command) {
		printUsage();
		return -1;
	}

	// Initialize Winsock
	WORD wVersionRequested = MAKEWORD( 1, 1 );
	WSADATA wsaData;
	int err = WSAStartup( wVersionRequested, &wsaData );
	if ( err != 0 ) {
		fprintf(stderr, "SW: Couldn't initialize winsock\n");
		return -1;
	}

	// Connect to the specified ports
	SOCKET inputSocket = INVALID_SOCKET, outputSocket = INVALID_SOCKET;
	HANDLE inputSocketDup = INVALID_HANDLE_VALUE, outputSocketDup = INVALID_HANDLE_VALUE;
	int iMode = 0;
	struct sockaddr_in addr;
	
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	if (inputPort != 0) {
		inputSocket = WSASocket(AF_INET, SOCK_STREAM, 0, NULL, 0, 0);
		if (inputSocket == INVALID_SOCKET) {
			fprintf(stderr, "SW: Error creating input socket: %d\n", WSAGetLastError());
			return -1;
		}
		ioctlsocket(inputSocket, FIONBIO, (u_long FAR*) &iMode);

		addr.sin_port = htons(inputPort);
		if (connect(inputSocket, (const sockaddr*)&addr, 
					sizeof(addr)) == SOCKET_ERROR) {
			fprintf(stderr, "SW: Error connecting to input socket: %d\n", WSAGetLastError());
			return -1;
		}

		if (!DuplicateHandle(GetCurrentProcess(), (HANDLE)inputSocket,
						     GetCurrentProcess(), &inputSocketDup, 0,
							 TRUE, DUPLICATE_SAME_ACCESS)) {
			fprintf(stderr, "SW: Error duplicating input handle: %d\n",
					GetLastError());
			return -1;
		}
	}

	if (outputPort != 0) {
		outputSocket = WSASocket(AF_INET, SOCK_STREAM, 0, NULL, 0, 0);
		if (outputSocket == INVALID_SOCKET) {
			fprintf(stderr, "SW: Error creating output socket: %d\n", WSAGetLastError());
			return -1;
		}
		ioctlsocket(outputSocket, FIONBIO, (u_long FAR*) &iMode);

		addr.sin_port = htons(outputPort);
		if (connect(outputSocket, (const sockaddr*)&addr, 
					sizeof(addr)) == SOCKET_ERROR) {
			fprintf(stderr, "SW: Error connecting to output socket: %d\n", WSAGetLastError());
			return -1;
		}

		if (!DuplicateHandle(GetCurrentProcess(), (HANDLE)outputSocket,
						     GetCurrentProcess(), &outputSocketDup, 0,
							 TRUE, DUPLICATE_SAME_ACCESS)) {
			fprintf(stderr, "SW: Error duplicating output handle: %d\n", GetLastError());
			return -1;
		}
	}

	// Find out how many processes we need to spawn
	int numProcesses = 0;
	LPSTR token = strtok(command, "|");
	while (token) {
		numProcesses++;
		token = strtok(NULL, "|");
	}

	// Allocate process handle array (+1 for NPIPE move thread handle)
	PHANDLE pProcessHandles = new HANDLE[numProcesses+1];
	PHANDLE pThreadHandles = new HANDLE[numProcesses+1];
	for (int i = 0; i < (numProcesses+1); i++) {
		pProcessHandles[i] = INVALID_HANDLE_VALUE;
		pThreadHandles[i] = INVALID_HANDLE_VALUE;
	}

	// Check for PIPE_TOKEN in first command and set vars for named pipe mode
	LPSTR lpszCmdBuf = (LPSTR)malloc (strlen(command)+1);
	LPSTR lpszCmdWithPipe = (LPSTR)malloc (strlen(command)+strlen(PIPE_NAME_ROOT)+8);
	LPSTR lpszPipeName = (LPSTR)malloc (strlen(PIPE_NAME_ROOT)+7);
	if (!lpszCmdBuf || !lpszCmdWithPipe || !lpszPipeName){
		fprintf(stderr, "SW: Error Allocating String Buffers\n");
		return -1;
	}
	sprintf(lpszPipeName, "%s%06d", PIPE_NAME_ROOT, getpid());
	strcpy(lpszCmdBuf,command);
	LPSTR p = strstr(lpszCmdBuf, PIPE_TOKEN);
	if (p == NULL) {
		p = strstr(lpszCmdBuf, DEBUG_PIPE_TOKEN);
		bDebug = (p != NULL);
	}
	BOOL bUseNamedPipe = (p != NULL);
	if (bUseNamedPipe) {
		*p = '\0';
		bDebug ? p = p+strlen( DEBUG_PIPE_TOKEN ) : p = p+strlen( PIPE_TOKEN );
		sprintf(lpszCmdWithPipe, "%s%s%s", lpszCmdBuf, lpszPipeName, p); 
	}

	// Now create the processes and the pipes between them
	token = command;
	HANDLE hNextInput = (inputSocketDup == INVALID_HANDLE_VALUE) ? 
		GetStdHandle(STD_INPUT_HANDLE) : inputSocketDup;
	for (int i = 0; i < numProcesses; i++) {
		HANDLE hInput = hNextInput, hOutput;
		// If this is the last process, use the output socket
		if (i == numProcesses-1) {
			hOutput = (outputSocketDup == INVALID_HANDLE_VALUE) ? 
				GetStdHandle(STD_OUTPUT_HANDLE) : outputSocketDup;
		}
		// Otherwise, create a pipe to connect to the next process
		else {
			SECURITY_ATTRIBUTES saAttr; 

			saAttr.nLength = sizeof(SECURITY_ATTRIBUTES); 
			saAttr.bInheritHandle = TRUE; 
			saAttr.lpSecurityDescriptor = NULL; 
			
			HANDLE hPipeReader, hPipeWriter;
			if (!CreatePipe(&hPipeReader,
							&hPipeWriter, 
							&saAttr, 0)){
				fprintf(stderr, "SW: Error Creating Pipe: %d\n", GetLastError());
				KillAllProcesses(pProcessHandles, numProcesses);
				return -1;
			}

			hOutput = hPipeWriter;
			hNextInput = hPipeReader;
		}
		if (i == 0 && bUseNamedPipe) {
			//Create Named Pipe
			HANDLE hNPipe = CreateNamedPipe(lpszPipeName,
											PIPE_ACCESS_INBOUND,
											PIPE_TYPE_BYTE|PIPE_WAIT,
											1,
											BUFFER_SIZE,
											BUFFER_SIZE,
											INFINITE,
											NULL);
			if(hNPipe == INVALID_HANDLE_VALUE) {
				fprintf(stderr,"SW: Error Creating Named Pipe: %d\n", GetLastError());
				KillAllProcesses(pProcessHandles, numProcesses);
				return -1;
			}
			if (bDebug)
				fprintf(stderr, "SW: Created Named Pipe: %s\n", lpszPipeName);
			hRWReader = hNPipe;
			hRWWriter = hOutput;
			hOutput = GetStdHandle(STD_ERROR_HANDLE);
		}

		STARTUPINFO siStartInfo;
		PROCESS_INFORMATION piProcInfo; 
	
		ZeroMemory(&piProcInfo, sizeof(PROCESS_INFORMATION));

		ZeroMemory(&siStartInfo, sizeof(STARTUPINFO));
		siStartInfo.cb = sizeof(STARTUPINFO); 
		siStartInfo.hStdError = GetStdHandle(STD_ERROR_HANDLE);
		siStartInfo.hStdOutput = hOutput;
		siStartInfo.hStdInput = hInput;
		siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

		BOOL bFuncRetn; 
		bFuncRetn = CreateProcess(NULL, 
								  (i == 0 && bUseNamedPipe) ? lpszCmdWithPipe : token,   // command line 
								  NULL, // process security attributes 
								  NULL, // primary thread security attributes 
								  TRUE, // handles are inherited 
								  0,    // creation flags 
								  NULL, // use parent's environment 
								  NULL, // use parent's current directory 
								  &siStartInfo,  // STARTUPINFO pointer 
								  &piProcInfo);  // receives PROCESS_INFORMATION 
		if (bFuncRetn == 0) {
			fprintf(stderr, "SW: Error creating child process: %d\n", GetLastError());
			KillAllProcesses(pProcessHandles, numProcesses);
			return -1;
		}
		if (bDebug)
			fprintf(stderr, "SW: Created child process with command line: %s\n", (i == 0 && bUseNamedPipe) ? lpszCmdWithPipe : token );

		pProcessHandles[i] = piProcInfo.hProcess;
		pThreadHandles[i] = piProcInfo.hThread;

		// Skip over null and leading space
		token += strlen(token) + 2;
	}		
	
	if (bUseNamedPipe) {
		// Socketwrapper has to transfer data from the named pipe to the next process in the command chain
		if (numProcesses == 1) {
			HANDLE hWRWriter = (outputSocketDup == INVALID_HANDLE_VALUE) ? GetStdHandle(STD_OUTPUT_HANDLE) : outputSocketDup;
		}
		VOID *pTransferBuffer = malloc(BUFFER_SIZE);
		if (pTransferBuffer) {
			// Create thread to transfer data from NPIPE to second command
			PHANDLE hMoveThread = (PHANDLE)_beginthreadex(NULL, 0, &MoveData, pTransferBuffer, 0, NULL);
			if (hMoveThread) {
				SetThreadPriority(hMoveThread, THREAD_PRIORITY_TIME_CRITICAL);
				// Monitor thread and other processes for exit or no data moved by thread in TIMEOUT
				pProcessHandles[numProcesses] = hMoveThread; // add thread to array of processes which is monitored
				DWORD timeOut = bDebug ? DEBUG_TIMEOUT : TIMEOUT;
				UINT lastWDCount = 0;
				while ((WaitForMultipleObjects(numProcesses+1, pProcessHandles, FALSE, timeOut) == WAIT_TIMEOUT)
					   && (lastWDCount != watchDogCount))
					lastWDCount = watchDogCount;
				if (bDebug && (lastWDCount == watchDogCount))
					fprintf(stderr, "SW: Transfer stalled            \n");
				// Kill thread if still running
				DWORD ThreadStatus;
				GetExitCodeThread(hMoveThread, &ThreadStatus );
				if (ThreadStatus == STILL_ACTIVE) {
					if (bDebug)
						fprintf(stderr, "SW: Killing MoveData thread\n");
					TerminateThread(hMoveThread, 0);
				}
				CloseHandle(hMoveThread);
			}
			else {
				fprintf(stderr, "SW: Error creating thread to move data\n");
			}
			free(pTransferBuffer);
		}
		else {
			fprintf(stderr, "SW: Error allocating memory for transfer buffer\n");
		}
		// Clean up 
		DisconnectNamedPipe(hRWReader);
		CloseHandle(hRWReader);
	}
	else {
		// Wait until at least one process dies
		WaitForMultipleObjects(numProcesses, pProcessHandles, FALSE, INFINITE);
	}

	KillAllProcesses(pProcessHandles, numProcesses);
	for (int i = 0; i < numProcesses; i++) {
		CloseHandle(pThreadHandles[i]);
	}
	delete [] pProcessHandles;
	delete [] pThreadHandles;
	free(lpszCmdBuf);
	free(lpszCmdWithPipe);
	free(lpszPipeName);

	if (inputSocket != INVALID_SOCKET) {
		closesocket(inputSocket);
		CloseHandle(inputSocketDup);
	}

	if (outputSocket != INVALID_SOCKET) { 
		closesocket(inputSocket);
		CloseHandle(inputSocketDup);
	}

	WSACleanup();

	return 0;
}
