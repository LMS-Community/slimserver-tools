
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

#include "stdafx.h"
#include "getopt.h"

static char* gOptionStr = "i:o:c:";

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

DWORD main(int argc, char **argv) 
{
	USHORT inputPort = -1, outputPort = -1;
	LPSTR command = NULL;

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

	WORD wVersionRequested = MAKEWORD( 1, 1 );
	WSADATA wsaData;
	int err = WSAStartup( wVersionRequested, &wsaData );
	if ( err != 0 ) {
		fprintf(stderr, "Couldn't initialize winsock\n");
		return -1;
	}

	SOCKET inputSocket = INVALID_SOCKET, outputSocket = INVALID_SOCKET;
	HANDLE inputSocketDup = INVALID_HANDLE_VALUE, outputSocketDup = INVALID_HANDLE_VALUE;
	int iMode = 0;
	struct sockaddr_in addr;
	
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	if (inputPort != -1) {
		inputSocket = WSASocket(AF_INET, SOCK_STREAM, 0, NULL, 0, 0);
		if (inputSocket == INVALID_SOCKET) {
			fprintf(stderr, "Error creating input socket: %d\n", WSAGetLastError());
			return -1;
		}
		ioctlsocket(inputSocket, FIONBIO, (u_long FAR*) &iMode);

		addr.sin_port = htons(inputPort);
		if (connect(inputSocket, (const sockaddr*)&addr, 
					sizeof(addr)) == SOCKET_ERROR) {
			fprintf(stderr, "Error connecting to input socket: %d\n", WSAGetLastError());
			return -1;
		}

		if (!DuplicateHandle(GetCurrentProcess(), (HANDLE)inputSocket,
						     GetCurrentProcess(), &inputSocketDup, 0,
							 TRUE, DUPLICATE_SAME_ACCESS)) {
			fprintf(stderr, "Error duplicating input handle: %d\n",
					GetLastError());
			return -1;
		}
	}

	if (outputPort != -1) {
		outputSocket = WSASocket(AF_INET, SOCK_STREAM, 0, NULL, 0, 0);
		if (outputSocket == INVALID_SOCKET) {
			fprintf(stderr, "Error creating output socket: %d\n", WSAGetLastError());
			return -1;
		}
		ioctlsocket(outputSocket, FIONBIO, (u_long FAR*) &iMode);

		addr.sin_port = htons(outputPort);
		if (connect(outputSocket, (const sockaddr*)&addr, 
					sizeof(addr)) == SOCKET_ERROR) {
			fprintf(stderr, "Error connecting to output socket: %d\n", WSAGetLastError());
			return -1;
		}

		if (!DuplicateHandle(GetCurrentProcess(), (HANDLE)outputSocket,
						     GetCurrentProcess(), &outputSocketDup, 0,
							 TRUE, DUPLICATE_SAME_ACCESS)) {
			fprintf(stderr, "Error duplicating output handle: %d\n",
					GetLastError());
			return -1;
		}
	}

	STARTUPINFO siStartInfo;
	PROCESS_INFORMATION piProcInfo; 
	
	ZeroMemory(&piProcInfo, sizeof(PROCESS_INFORMATION));

	ZeroMemory( &siStartInfo, sizeof(STARTUPINFO) );
	siStartInfo.cb = sizeof(STARTUPINFO); 
	siStartInfo.hStdError = GetStdHandle(STD_ERROR_HANDLE);
	siStartInfo.hStdOutput = (outputSocketDup == INVALID_HANDLE_VALUE) ? GetStdHandle(STD_OUTPUT_HANDLE) : outputSocketDup;
	siStartInfo.hStdInput = (inputSocketDup == INVALID_HANDLE_VALUE) ? GetStdHandle(STD_INPUT_HANDLE) : inputSocketDup;
	siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

	BOOL bFuncRetn; 
	bFuncRetn = CreateProcess(NULL, 
				  command,   // command line 
				  NULL,      // process security attributes 
				  NULL,      // primary thread security attributes 
				  TRUE,      // handles are inherited 
				  0,         // creation flags 
				  NULL,      // use parent's environment 
				  NULL,      // use parent's current directory 
				  &siStartInfo,  // STARTUPINFO pointer 
				  &piProcInfo);  // receives PROCESS_INFORMATION 
	if (bFuncRetn == 0) {
		fprintf(stderr, "Error creating child process: %d\n", 
			GetLastError());
		return -1;
	}

	WaitForSingleObject(piProcInfo.hProcess, INFINITE);

	CloseHandle(piProcInfo.hProcess);
	CloseHandle(piProcInfo.hThread);

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
