%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


struct Symbol {
    char *name;
    struct Symbol *next;
};
struct Symbol *symbol_table = NULL;

void add_symbol(char *name) {
    struct Symbol *ptr = symbol_table;
    while (ptr != NULL) {
        if (strcmp(ptr->name, name) == 0) {
            printf("Error: Variable '%s' is already declared!\n", name);
            exit(1);
        }
        ptr = ptr->next;
    }
    struct Symbol *new_sym = (struct Symbol *)malloc(sizeof(struct Symbol));
    new_sym->name = strdup(name);
    new_sym->next = symbol_table;
    symbol_table = new_sym;
}

void check_declared(char *name) {
    struct Symbol *ptr = symbol_table;
    while (ptr != NULL) {
        if (strcmp(ptr->name, name) == 0) return;
        ptr = ptr->next;
    }
    printf("Semantic Error: Variable '%s' used but not declared.\n", name);
    exit(1);
}



typedef enum { N_DECL, N_ASSIGN, N_PRINT, N_PRINT_STR, N_IF, N_BINOP, N_NUM, N_ID, N_STMTLIST } NodeType;

typedef struct Node {
    NodeType type;
    char *sval;
    int  ival;
    struct Node *left;
    struct Node *right;
    struct Node *next;
} Node;

void yyerror(const char *s);
int yylex(void);
extern FILE *yyin;


Node* mknode(NodeType t, const char *s, int val, Node *l, Node *r);
Node* append_stmt(Node *head, Node *stmt);
void print_tree_visual(Node *n, int depth, int is_last, int mask);
void generate_target_code(Node *stmts);

%}

%union {
    int num;
    char *id;
    char *str;   
    Node *node;  
}

%token <num> NUMBER
%token <id> ID
%token <str> STRING 
%token INT PRINT IF ELSE

%token EQ NEQ LT GT LE GE

%right '='       
%left EQ NEQ
%left LT GT LE GE
%left '+' '-'
%left '*' '/' 
%right UMINUS   
  
%type <node> expr statement stmt_list block

%%

program:
    stmt_list {
        printf("\n--- VISUAL PARSE TREE ---\n");
        print_tree_visual($1 ? mknode(N_STMTLIST, NULL, 0, $1, NULL) : NULL, 0, 1, 0);
        printf("-------------------------\n\n");
        generate_target_code($1);
    }
    ;

stmt_list:
      /* empty */ { $$ = NULL; }
    | stmt_list statement { $$ = $1 ? append_stmt($1, $2) : $2; }
    ;

statement:
      INT ID ';' { // int x ;
          add_symbol($2); 
          $$ = mknode(N_DECL, $2, 0, NULL, NULL); 
          free($2); 
      }
    | INT ID '=' expr ';' {  // int x = 2 * 8 ;
          add_symbol($2); 
          $$ = mknode(N_DECL, $2, 0, $4, NULL); 
          free($2); 
      }
    | expr ';' { 
          $$ = $1; 
      }

    | PRINT '(' expr ')' ';' { $$ = mknode(N_PRINT, NULL, 0, $3, NULL); }
    
    | PRINT '(' STRING ')' ';' { 
          $$ = mknode(N_PRINT_STR, $3, 0, NULL, NULL); 
        
      }
    | IF '(' expr ')' block { // if(x < y){}
          $$ = mknode(N_IF, NULL, 0, $3, $5);
      }
    | IF '(' expr ')' block ELSE block {// if(x < y){}else{}
          Node *ifn = mknode(N_IF, NULL, 0, $3, $5);
          ifn->next = $7;
          $$ = ifn;
      }
    ;
block:
      '{' stmt_list '}' { $$ = mknode(N_STMTLIST, NULL, 0, $2, NULL); }
    ;

expr:
      ID '=' expr { 
          check_declared($1); 
          $$ = mknode(N_ASSIGN, $1, 0, $3, NULL); 
          free($1); 
      }
    | expr '+' expr { $$ = mknode(N_BINOP, "+", 0, $1, $3); }
    | expr '-' expr { $$ = mknode(N_BINOP, "-", 0, $1, $3); }
    | expr '*' expr { $$ = mknode(N_BINOP, "*", 0, $1, $3); }
    | expr '/' expr { $$ = mknode(N_BINOP, "/", 0, $1, $3); }
    | expr EQ expr  { $$ = mknode(N_BINOP, "==", 0, $1, $3); }
    | expr NEQ expr { $$ = mknode(N_BINOP, "!=", 0, $1, $3); }
    | expr LT expr  { $$ = mknode(N_BINOP, "<", 0, $1, $3); }
    | expr GT expr  { $$ = mknode(N_BINOP, ">", 0, $1, $3); }
    | expr LE expr  { $$ = mknode(N_BINOP, "<=", 0, $1, $3); }
    | expr GE expr  { $$ = mknode(N_BINOP, ">=", 0, $1, $3); } 
    | '-' expr %prec UMINUS { $$ = mknode(N_BINOP, "neg", 0, $2, NULL); } // -(1 + 2 * 5)
    | '(' expr ')' { $$ = $2; }
    | NUMBER { $$ = mknode(N_NUM, NULL, $1, NULL, NULL); }
    | ID { 
          check_declared($1); 
          $$ = mknode(N_ID, $1, 0, NULL, NULL); 
          free($1); 
      }
    ;

%%



Node* mknode(NodeType t, const char *s, int val, Node *l, Node *r) {
    Node *n = malloc(sizeof(Node));
    if (!n) { perror("malloc"); exit(1); }
    n->type = t;
    n->sval = s ? strdup(s) : NULL;
    n->ival = val;
    n->left = l;
    n->right = r;
    n->next = NULL;
    return n;
}

Node* append_stmt(Node *head, Node *stmt) {
    if (!head) return stmt;
    Node *p = head;
    while (p->next) p = p->next;
    p->next = stmt;
    return head;
}


void print_branch(int depth, int is_last, int mask) {
    for (int i = 0; i < depth - 1; i++) {
        if (mask & (1 << i)) printf("|   ");
        else printf("    ");
    }
    if (depth > 0) {
        if (is_last) printf("+-- ");
        else printf("|-- ");
    }
}

void print_tree_visual(Node *n, int depth, int is_last, int mask) {
    if (!n) return;
    print_branch(depth, is_last, mask);
    
    switch (n->type) {
        case N_DECL:    printf("DECL (%s)\n", n->sval); break;
        case N_ASSIGN:  printf("ASSIGN (=) %s\n", n->sval); break;
        case N_PRINT:   printf("PRINT (Expr)\n"); break;
        /* NEW: Visual for String Print */
        case N_PRINT_STR: printf("PRINT (String): %s\n", n->sval); break;
        case N_IF:      printf("IF\n"); break;
        case N_BINOP:   printf("OP (%s)\n", n->sval); break;
        case N_NUM:     printf("NUM (%d)\n", n->ival); break;
        case N_ID:      printf("ID (%s)\n", n->sval); break;
        case N_STMTLIST:printf("BLOCK\n"); break;
        default:        printf("UNKNOWN\n"); break;
    }

    int next_mask = mask;
    if (!is_last) next_mask |= (1 << depth);

    if (n->type == N_STMTLIST) {
        Node *child = n->left;
        while (child) {
            print_tree_visual(child, depth + 1, child->next == NULL, next_mask);
            child = child->next;
        }
    } else {
        if (n->left && n->right) {
            print_tree_visual(n->left, depth + 1, 0, next_mask);
            print_tree_visual(n->right, depth + 1, 1, next_mask);
        } else if (n->left) {
            print_tree_visual(n->left, depth + 1, 1, next_mask);
        } else if (n->right) {
            print_tree_visual(n->right, depth + 1, 1, next_mask);
        }
    }
}


void gen_expr(FILE *out, Node *n) {
    if (!n) return;
    switch (n->type) {
        case N_NUM: fprintf(out, "%d", n->ival); break;
        case N_ID: fprintf(out, "%s", n->sval); break;
        case N_ASSIGN:
            fprintf(out, "(%s = ", n->sval);
            gen_expr(out, n->left);
            fprintf(out, ")");
            break;
        case N_BINOP:
            if (strcmp(n->sval, "neg") == 0) { // 
                fprintf(out, "(-");       // Print the minus sign FIRST
                gen_expr(out, n->left);   // Then print the number
                fprintf(out, ")");
            } 
            else {
                fprintf(out, "("); 
                gen_expr(out, n->left);
                fprintf(out, " %s ", n->sval);
                gen_expr(out, n->right); 
                fprintf(out, ")");
            }
            break;
        default: break;
    }
}

void gen_stmt(FILE *out, Node *s, int indent) {
    if (!s) return;
    for (int i = 0; i < indent; i++) fprintf(out, "    ");
    
    switch (s->type) {
        case N_DECL:
            fprintf(out, "int %s", s->sval);
            if (s->left) { // int x;
                 fprintf(out, " = ");
                 gen_expr(out, s->left);
            }
            fprintf(out, ";\n");
            break;
        case N_PRINT:
            /* Standard integer print */ 
            fprintf(out, "printf(\"%%d\\n\", "); gen_expr(out, s->left); fprintf(out, ");\n");
            break;
        case N_PRINT_STR:
            /* NEW: String print (sval already contains the quotes "...") */
            fprintf(out, "printf(\"%%s\\n\", %s);\n", s->sval);
            break;
        case N_IF:
            fprintf(out, "if ("); gen_expr(out, s->left); fprintf(out, ") {\n");
            if (s->right && s->right->type == N_STMTLIST) {
                for (Node *p = s->right->left; p; p = p->next) gen_stmt(out, p, indent+1);
            }
            for (int i = 0; i < indent; i++) fprintf(out, "    ");
            fprintf(out, "}");
            if (s->next && s->next->type == N_STMTLIST) {
                fprintf(out, " else {\n");
                for (Node *p = s->next->left; p; p = p->next) gen_stmt(out, p, indent+1);
                for (int i = 0; i < indent; i++) fprintf(out, "    "); fprintf(out, "}\n");
            } else fprintf(out, "\n");
            break;
        case N_STMTLIST: 
             break;
        default:
            gen_expr(out, s);
            fprintf(out, ";\n");
            break;
    }
}

void execute_generated_code() {
    printf("\n--- EXECUTION RESULTS ---\n");
    int compile_status = system("gcc output.c -o program");
    if (compile_status != 0) {
        printf("Error: Compilation failed.\n");
        return;
    }
    int run_status = system("program > result.txt");
    if (run_status == 0) {
        FILE *fp = fopen("result.txt", "r");
        if (fp) {
            char ch;
            while ((ch = fgetc(fp)) != EOF) putchar(ch);
            fclose(fp);
            printf("\n(Output saved to 'result.txt')\n");
        } else {
            printf("Error reading result.txt\n");
        }
    }
    printf("-------------------------\n");
}

void generate_target_code(Node *stmts) {
    FILE *out = fopen("output.c", "w");
    if (!out) { perror("fopen output.c"); return; }
    
    fprintf(out, "#include <stdio.h>\n#include <stdlib.h>\n\nint main() {\n");
    for (Node *p = stmts; p; p = p->next) gen_stmt(out, p, 1);
    fprintf(out, "    return 0;\n}\n");
    fclose(out);
    
    execute_generated_code();
}

void yyerror(const char *s) { fprintf(stderr, "Parse error: %s\n", s); }

int main() {
    FILE *myfile = fopen("input.txt", "r");
    if (!myfile) {
        printf("Error: Cannot open 'input.txt'!\n");
        return -1;
    }
    yyin = myfile;
    yyparse();
    fclose(myfile);
    return 0;
}