# wiki.slimdevices.com AWS Lambda@Edge

This is a simple Lambda@Edge script to be used in AWS CloudFront with the now static wiki.slimdevices.com mirror. 
As all the file names have been re-written with an `.html` extension, and some special characters replaced 
(eg. `User:xyz` -> `User_xyz.html`), this Lambda would do the same to get the correct file from the S3 bucket.

It must be registered as a `viewer-request` event. The execution role needs an additional trust relationship for `edgelambda.amazonaws.com`.