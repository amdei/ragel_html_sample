# ragel_html_sample

In my project I need to extract links from HTML document.
For this purpose I've prepared ragel HTML grammar, primarily based on this work:
https://github.com/brianpane/jitify-core/blob/master/src/core/jitify_html_lexer.rl
(mentioned here: http://ragel-users.complang.narkive.com/qhjr33zj/ragel-grammars-for-html-css-and-javascript )


Almost all works well (thanks for the great tool!), except one issue I can't overcome to date:

If I specify this thext as an input:
    bbbb <a href="first_link.aspx">  cccc<a href="/second_link.aspx">
my parser can correctly extract first link, but not the second one.
The difference between them is that there is a space between 'bbbb' and '<a', but no spaces between 'cccc' and '<a'.

In general, if any text, except spaces, exists before '<a' tag it makes parses consider it as content, and parser do not recognize tag opening.


Please find in this repo intentionally simplified sample with grammar, aiming to work as C program ( ngx_url_html_portion.rl ).
There is also input file input-nbsp.html , which expected to contain input for the application.

In order to play with it, make .c-file from grammar:
    ragel ngx_url_html_portion.rl
then compile resulting .c-file and run programm.
Input file should be in the same directory.
