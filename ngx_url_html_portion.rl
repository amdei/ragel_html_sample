#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>


#define BUF_SIZE 4096
#define BUF_SIZE_HREF 2000

%%{
    machine simple;
    write data;
}%%
    
u_char *href_buf;

typedef struct {
    int cs;
    u_char *plain_before_href;
    u_char *href_start_pos;
    u_char *href_buffer_pos;
    int inside_href;
} par_t;

void copy2hrefbuf(par_t* par, u_char* p){
    size_t href_len = p - par->href_start_pos;
    
    size_t need_buffer = par->href_buffer_pos - href_buf + href_len;
    if(need_buffer > BUF_SIZE_HREF){
        printf("\nHref too long (%d)!\n", need_buffer);
    }else{
        memcpy(par->href_buffer_pos, par->href_start_pos, href_len);
        par->href_buffer_pos += href_len;
    }
}

%%{
    action start_anchor {
            printf("Start anchor\n");
    }

    action href_internal{
            printf("%c", fc);
    }
    
    action inside_content {
            printf("Content: %c\n", fc);    
    }

    action inside_space {
            printf("  Space: %c\n", fc);    
    }

    action href_internal_start{
            printf("href start\n");
            assert(!par->inside_href && "Already in HREF!");
            par->inside_href = 1;
            fwrite(par->plain_before_href, (p - par->plain_before_href), 1, fpw);
            par->href_start_pos = p;
            par->href_buffer_pos = href_buf;
            memset(href_buf, 0, BUF_SIZE_HREF);
    }

    action href_internal_end{
            printf("\nhref end\n");
            par->inside_href = 0;
            par->plain_before_href = fpc;
            
            copy2hrefbuf(par, p);
            
            // For safety.
            par->href_start_pos = NULL;
    }

    action end_anchor {
            printf("\nEnd anchor\n");
    }

    tag_close = '/'? '>';

    name_char = (alnum | '-' | '_' | '.' | ':');
    name_start_char = (alpha | '_');
    name = name_start_char name_char**;

    misc_directive = any* :>> '>';

    directive = (
      '!' (misc_directive)
    );

    attr_name = (
      alpha (alnum | '-' | '_' | ':')**
    );

    unquoted_attr_char = ( any - ( space | '>' | '\\' | '"' | "'" ) );
    unquoted_attr_value = (unquoted_attr_char unquoted_attr_char**);

    single_quoted_attr_value = "'" ( /[^']*/ ) "'";

    double_quoted_attr_value = '"' ( /[^"]*/ ) '"';

    attr_value = (
      unquoted_attr_value |
      single_quoted_attr_value  |
      double_quoted_attr_value
    );

    tag_attrs = (space+ ( attr_name <: space* ( '=' space* attr_value <: space*)? )*);

    href_attr_name = 'href';

    tag_attrs_of_intrest = (space+ ( (href_attr_name) 
                         <: space* ( '=' space* attr_value 
                                >href_internal_start 
                                $href_internal 
                                %href_internal_end 
                         <: space*)? )*);

    misc_tag = (
      '/'?
      attr_name
      tag_attrs?
      tag_close
    );


    misc_tag_of_intrest = (
      tag_attrs* tag_attrs_of_intrest? tag_attrs*
      tag_close
    );


    element = (
      misc_tag
      |
      directive
    );


    element_of_intrest = (
      misc_tag_of_intrest
      |
      directive
    );

    content = (
      any - (space )
    )+;

    html_space = (
      ( space - ( '\r' | '\n' ) ) |
      ( '\r' | '\n' )
    )+;

    anchor_element = '<a';

    main := 
      (
        ( anchor_element element_of_intrest >start_anchor %end_anchor)
        |
        (( '<' element ) - (anchor_element) )
        |
        html_space $inside_space
        |
        content  $inside_content
      )** 
    ;

}%%

void par_exec(par_t *par, void *buf, size_t buf_len, int is_endOfData, FILE *fpw) {
    int cs = par->cs;
    u_char *p = buf;
    u_char *pe = NULL == buf ? NULL : p + buf_len;
    u_char *eof = NULL;
    par->plain_before_href = p;

    /* If no data was read indicate EOF. */
    if(is_endOfData){
        eof = pe;
    }
    
    if(par->inside_href){
        par->href_start_pos = p;
    }

    %% write exec;

    par->cs = cs;
    if(pe - p >= BUF_SIZE){
        printf("\nNeed to buffer:%d", pe - p);
    }

    if(!is_endOfData){
        if(!par->inside_href){
            fwrite(par->plain_before_href, (p - par->plain_before_href), 1, fpw);
        }
        else{
            // Save href reminder in buffer for later parsing.
            copy2hrefbuf(par, p);
        }
    }    
}

int main(){
    
    FILE *fp;
    FILE *fpw;
    u_char input_buf[BUF_SIZE];
    u_char output_buf[BUF_SIZE];

    
    href_buf = malloc(BUF_SIZE_HREF);
        
    int cs;

    %%{
        write init;
    }%%

    par_t parser_state;
    parser_state.cs = cs;
    parser_state.plain_before_href = input_buf;
    parser_state.inside_href = 0;

    fp = fopen("input-nbsp.html","r");    
    if( fp == NULL )
    {
        perror("Error while opening the input file.\n");
        exit(EXIT_FAILURE);
    }    


    fpw = fopen("output.html","w");
    if( fp == NULL )
    {
        perror("Error while opening the output file.\n");
        exit(EXIT_FAILURE);
    }    
    
    while(1){
        int len = fread(input_buf, 1, sizeof(input_buf), fp);
        par_exec(&parser_state, input_buf, len, len == 0, fpw);
        if(len == 0)
            break;
    }
    free(href_buf);
    fclose(fp);
    fclose(fpw);
        

   return 0;    
}
