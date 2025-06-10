workflow-ng builds on existing Claude Code instance concurrency guidelines and improves the process. The root directory contains a number of 
folders, each named for their purpose. These folders will be filled with AI targeted documents as well as plain text files pertaining to their 
purpose. Documents stored in these folders are to be analyzed and used in building a Claude Code powered workflow that is:
effective,
efficient,
tech agnostic,
failsafe,
fast,
and designed to better facilitate and enable concurrent automated workers.

A current limitation is due to file based working. Work is claimed by writing to file, but if it is not kept current duplicate may be done by 
misguided Claude Code instances. This needs to be moved to a faster system designed for high throughput, such as redis.

The output of this project will be a set of documents that can be added to a new project directory for the purpose of informing the Claude Code 
/init process.


