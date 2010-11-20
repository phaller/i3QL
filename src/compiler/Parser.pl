/* License (BSD Style License):
   Copyright (c) 2010
   Department of Computer Science
   Technische Universität Darmstadt
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are met:

    - Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    - Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    - Neither the name of the Software Technology Group or Technische 
      Universität Darmstadt nor the names of its contributors may be used to 
      endorse or promote products derived from this software without specific 
      prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
   AND ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
   POSSIBILITY OF SUCH DAMAGE.
*/


/**
	A parser for (ISO) Prolog programs.</br>
	<p>
	<b>Prolog Grammar Specification</b><br/>
	<i>Notes</i><br/>
	Special cases that are not directly reflected by the following grammar, but
	which are handled by the parser, are:
	<ul>
	<li> "\+ (a,b)" and "\+(a,b)" are different statements; the first term
	is equivalent to "'\+'(','(a,b))" and the second statemet is just a 
	complex term with the functor "\+" and two arguments "a" and "b".</li>
	<li> "V=(a,b)" is equivalent to: "'='(V,(a,b))" ("'='(V,','(a,b))")</li>
	</ul><br />
	Furthermore, the priority of a complex term is always determined by the priority 
	of the complex term's operator, if the complex term is defined using the operator notation. E.g.,
	the priority of the term <code>a,b</code> is 1000; however, the priority
	of the complex term ','(a,b) is 0 (the priority of all elementary terms.)<br />
	<br />
	<i>Grammar</i>
	<code><pre>
	clause ::= term '.'

	term ::= prefix_op term
	term ::= term infix_op term
	term ::= term postfix_op
	term ::= elementary_term

	elementary_term ::= 
		string_atom | float_atom | integer_atom | 
		variable | 
		complex_term |
		list | nested_term | dcg_expr
	complex_term ::= functor'(' term{Priority&lt;1000} (',' term{Priority&lt;1000})* ')'	% NOTE no whitespace is allowed between the functor and the opening bracket 
	list ::= '[' list_elems? ']'
	list_elems ::= term{Priority&lt;1000} (',' term{Priority&lt;1000})*  ('|' term{Priority&lt;1000})? 
	nested_term ::= '(' term{Priority&lt;=1200} ')'
	dcg_expr ::= '{' term{Priority&lt;=1200} '}'

	prefix_op ::= string_atom
	postfix_op ::= string_atom
	infix_op ::= 
		string_atom | 
		functor % EXAMPLE "V=(A,B)"; here "=" is indeed an infix operator in functor postion

	integer_atom ::= &lt;an integer value&gt;
	float_atom ::= &lt;a floating point value&gt;
	functor ::= &lt;a string atom in functor position&gt;
	string_atom ::= &lt;either a sequence of characters enclosed in "'"'s, an 
			operator (sequence) or a "plain" name starting with a lower-case 
			letter&gt;
	variable ::= &lt;a "plain" name starting with an upper-case letter or "_"&gt;
	</pre></code>
	</p>
   
   @author Michael Eichberg (mail@michael-eichberg.de)	
*/
:- module(
   	'SAEProlog:Compiler:Parser',
   	[
      	clauses/2,
			default_op_table/1
   	]
	).

:- use_module('AST.pl').


/**
   Parses a list of tokens (<code>Ts</code>) and identifies all clauses.
 	The list of clauses encompasses (facts,) rules and directives.
	
	@signature program(TS,P)
	@arg(in) TS TS is a list of non-whitespace tokens as generated by the SAE lexer.
	@arg(out) P is the list of terms.
*/
clauses(Ts,Cs) :-
	default_op_table(Ops),
	clauses(Ops,Cs,Ts,X), % calls the corresponding DCG rule
	(	
		X=[],! % the parser succeeded (all tokens were accepted).
	;
		X=[T|_], % the parser failed while parsing the statement beginnig with T
		token_position(T,File,LN,CN),
		atomic_list_concat([File,':',LN,':',CN,': error: syntax error\n'],MSG), % GCC compliant
	   write(MSG),
		fail 
	).
		
		

/**
	The list of the default operators. 
	<p>
	This list is maintained using.
	<code>:- op(Priority, Op_Specifier, Operator) </code> directives which is
	always immediately evaluated by the parser.
	<code>op(Priority, Op_Specifier, Operator)</code> succeeds, with the side 
	effect that...
	<ul>
	<li>if Priority is 0 then Operator is removed from the operator table, else</li>
	<li>Operator is added to the Operator table, with the specified Priority (lower binds 
		tighter) and Associativity (determined by Op_Specifier according 
		to the rules):
		<pre>
			Specifier	Type		Associativity
			fx				prefix	no
			fy				prefix	yes
			xf				postfix	no
			yf				postfix	yes
			xfx			infix		no
			yfx			infix		left
			xfy			infix		right
		</pre>
	</li>
	</ul>
	It is forbidden to alter the priority or type of ','. It is forbidden to have
	an infix and a postfix operator with the same name, or two operators with the 
	same type and name.</br>
	<br />
	The initial operator table is given by:
	<pre>
	Priority	Specifier	Operator(s)
	1200		xfx			:- -->
	1200		fx				:- ?-
	1100		xfy			;
	1050		xfy			->
	1000		xfy			,
	900		fy				\+
	700		xfx			= \=
	700		xfx			== \== @< @=< @> @>=
	700		xfx			=..
	700		xfx			is =:= =\= < =< > >=
	500		yfx			+ - /\ \/
	400		yfx			* / // rem mod << >>
	200		xfx			**
	200		xfy			^
	200		fy				- \
	</pre>
	Parts of this text are taken from: 
	<a href="http://pauillac.inria.fr/~deransar/prolog/bips.html">
	http://pauillac.inria.fr/~deransar/prolog/bips.html
	</a>.
	</p>

	@signature default_op_table(Ops)
	@mode det()
	@arg(out) Ops Ops has the following structure:<br/>
		<code>ops(PrefixOperators,InfixOperators,PostfixOperators)</code> where
		PrefixOperators is the list of all predefined prefix operators, 
		InfixOperators is the list of all predefined infix Operators, and
		PostfixOperators is the list of all predefined postfix operators.
*/
default_op_table(
	ops(
		[  % PREFIX...
			op(900,fy,'\\+'),
			op(200,fy,'-'),	
			op(200,fy,'\\'), % bitwise complement
			op(1200,fx,':-'),
			op(1200,fx,'?-')			
		],
		[	% INFIX...
			op(1200,xfx,':-'),
			op(1200,xfx,'-->'),
			op(1100,xfy,';'),
			op(1000,xfy,','), % Redefining "and" is NOT supported!
			op(700,xfx,'='),
			op(500,yfx,'-'),
			op(500,yfx,'+'),
			op(1050,xfy,'->'),
			op(400,yfx,'*'),
			op(400,yfx,'/'),
			op(700,xfx,'\\='),
			op(700,xfx,'is'),
			op(700,xfx,'<'),
			op(700,xfx,'>'),
			op(700,xfx,'=<'),
			op(700,xfx,'>='),
			op(700,xfx,'=:='),
			op(700,xfx,'=\\='),	
			op(700,xfx,'=..'),
			op(700,xfx,'=='),
			op(700,xfx,'\\=='),
			op(700,xfx,'@<'),
			op(700,xfx,'@=<'),
			op(700,xfx,'@>'),
			op(700,xfx,'@>='),		
			op(500,yfx,'\\/'),
			op(500,yfx,'/\\'),	
			op(1100,xfy,'|'), % also defined by SWI Prolog
			op(400,yfx,'//'), % X // Y Division mit Ganzzahlergebnis
			op(400,yfx,'mod'),
			op(400,yfx,'<<'),
			op(400,yfx,'>>'),
			op(200,xfx,'**'),		
			op(200,xfy,'^')				
		],
		[	% POSTFIX...		
		]		
	)
).





/* ************************************************************************** *\
 *                                                                            *
 *                         I M P L E M E N T A T I O N                        *
 *                                                                            *
\* ************************************************************************** */


parser_error(ASTNode,MessageFragments) :-
	term_pos(ASTNode,File,LN,CN),
   atomic_list_concat(MessageFragments,EM),	
   atomic_list_concat([File,':',LN,':',CN,': error: ',EM,'\n'],MSG), % GCC compliant
   write(MSG).


/*
	The following pseudocode shows the underlying approach to parse Prolog terms 
	using Definite Clause Grammars (DCGs). 

	---- 1. Step - NAIVE GRAMMAR - NOT WORKING... (left recursive)
	term --> prefix_op, term.
	term --> [a(_)]
	term --> term, infix_op, term.
	term --> term, postfix_op.
	prefix_op --> [...].
	postfix_op --> [...].
	infix_op --> [...].

	---- 2. Step - AFTER LEFT RECURSION REMOVAL...
	term --> prefix_op, term, term_r.
	term --> [a(_)], term_r.

	term_r --> infix_op, term, term_r.
	term_r --> postfix_op, term_r.
	term_r --> [].

	prefix_op --> [...].
	postfix_op --> [...].
	infix_op --> [...].
	
	----- Remarks
	The operator table is made an argument of each rule and the default operator 
	table is defined by default_op_table.
*/
		

clauses(Ops,Clauses) --> 
	clause(Ops,Clause),
	{	!,	
		validate_clause(Clause) ->
			(	is_directive(Clause),!,
				process_directive(Ops,Clause,NewOps)
			;	% ... it is a "normal" clause
				Ops = NewOps
			),
			Clauses = [Clause|OtherClauses]
		;	% the clause is not valid; let's ignore it
			Clauses = OtherClauses,
			Ops = NewOps
	},
	clauses(NewOps,OtherClauses).
clauses(_Ops,[]) --> {true}.



% TODO check that the operator definition is valid 
% TODO check that no standard SAE Prolog operator is redefined
% TODO support the removal / redefinition of operators
% TODO check for discontiguous predicate definitions
process_directive(Ops,Directive,NewOps) :- 
	directive(Directive,GoalNode),	
	complex_term(GoalNode,Goal,Args),
	% IMPROVE (error) messages	
	(
		(
			Goal = op,
			process_op_directive(Args,Ops,NewOps)
		;
			Goal = module,
			Ops = NewOps,
			parser_error(Goal,['modules are not (yet) supported and module declarations are ignored'])
		;
			Goal = use_module,
			Ops = NewOps,
			parser_error(Goal,['modules are not (yet) supported and module declarations are ignored'])
		;
			Goal = ('discontiguous'),
			Ops = NewOps,
			parser_error(Goal,['the discontiguous directive is not yet supported'])
		),
		!
	;
		Ops = NewOps,	
		parser_error(GoalNode,['unknown directive: ',Goal])
	).
	
	
process_op_directive([PriorityNode,SpecifierNode,OperatorNode],ops(PrefixOps,InfixOps,PostfixOps),ops(NewPrefixOps,NewInfixOps,NewPostfixOps)) :- 
	integer_atom(PriorityNode,Priority),
	string_atom(SpecifierNode,Specifier),
	string_atom(OperatorNode,Operator),
	(  (Specifier = fx ; Specifier = fy),!,
		NewPrefixOps = [op(Priority,Specifier,Operator)|PrefixOps],
		NewInfixOps = InfixOps,
		NewPostfixOps = PostfixOps
	;	(Specifier = xfx ; Specifier = xfy ; Specifier = yfx),!,
		NewPrefixOps = PrefixOps,
		NewInfixOps = [op(Priority,Specifier,Operator)|InfixOps],
		NewPostfixOps = PostfixOps
	;	(Specifier = xf ; Specifier = yf),!,
		NewPrefixOps = PrefixOps,
		NewInfixOps = InfixOps,
		NewPostfixOps = [op(Priority,Specifier,Operator)|PostfixOps]
	;
		parser_error(SpecifierNode,['unknown specifier: ',Specifier]),
		NewPrefixOps = PrefixOps,
		NewInfixOps = InfixOps,
		NewPostfixOps = PostfixOps
	).



/**
	Validates a clause. If the clause is not valid an error 
	message is printed out to the console and this predicate fails. 
	
	@signature validate_clause(Clause) 
	@behavior semdet
	@arg(in) Clause A Clause.
*/
validate_clause(Clause) :- 
	is_variable(Clause),!,
	parser_error(Clause,['clause expected, but variable definition found']),
	fail.
validate_clause(Clause) :- 
	is_anonymous_variable(Clause),!,
	parser_error(Clause,['clause expected, but anonymous variable definition found']),
	fail. 
validate_clause(Clause) :- 
	is_numeric_atom(Clause),!,
	parser_error(Clause,['clause expected, but numeric value found']),
	fail.
validate_clause(Clause) :- 
	rule_head(Clause,Head),
	( is_variable(Head) ; is_anonymous_variable(Head) ; is_numeric_atom(Head) ),
	!,
	parser_error(Clause,['a clauses\'s head has to be a complex term or a string atom']),
	fail.
	
validate_clause(_Clause). % base case, the Clause is considered to be valid




/* ************************************************************************** *\
 *                                                                            *
 *                       T H E   C O R E   P A R S E R                        *
 *                                                                            *
\* ************************************************************************** */




clause(Ops,Term) --> 
	term(Ops,1200,Term,_TermPriority),
	[a('.',_Pos)],
	{!}. 


/**
	@signature term(Ops,MaxPriority,Term,TermPriority)
 	@arg(in) Ops The (current) table of operators.
	@arg(in) MaxPriority The maximum allowed priority for the term to be accepted.
	@arg(out) Term The accepted term.
	@arg(out) TermPriority The priority of the accepted term.
*/
term(Ops,MaxPriority,Term,TermPriority) --> 
	elementary_term(Ops,IntermediateTerm), 
	term_r(Ops,MaxPriority,IntermediateTerm,0,Term,TermPriority).
term(Ops,MaxPriority,Term,TermPriority) --> 
	prefix_op(Ops,op(Priority,Associativity,Op),Pos),
	{ 	MaxPriority >= Priority,
		(	Associativity = fx -> 
			MaxSubTermPriority is Priority - 1
		; %Associativity = fy 
			MaxSubTermPriority = Priority
		)
	}, 
	term(Ops,MaxSubTermPriority,SubTerm,_SubTermPriority), 
	{ complex_term(Op,[SubTerm],Pos,Ops,LeftTerm) },
	term_r(Ops,MaxPriority,LeftTerm,Priority,Term,TermPriority).

/**
	@signature term_r(Ops,MaxPriority,LeftTerm,LeftTermPriority,Term,TermPriority)
 	@arg(in) Ops The (current) table of operators.
	@arg(in) MaxPriority The maximum allowed priority for the term to be accepted.
	@arg(in) LeftTerm The left term.
	@arg(in) LeftTermPriority The priority of the left term.
	@arg(out) Term The accepted term.
	@arg(out) TermPriority The priority of the accepted term.
*/	
term_r(Ops,MaxPriority,LeftTerm,LeftTermPriority,Term,TermPriority) --> 
	infix_op(Ops,op(Priority,Associativity,Op),Pos),
	{	MaxPriority >= Priority,
		(	Associativity = yfx -> 
			Priority >= LeftTermPriority
		; %(Associativity = xfx, Associativity = xfy),
			Priority > LeftTermPriority
		)		
	},  
	term(Ops,Priority,RightTerm,RightTermPriority),
	{
		(	Associativity = xfy ->
			Priority >= RightTermPriority
		;	% (Associativity = xfx; Associativity = yfx),
			Priority > RightTermPriority
		),
		complex_term(Op,[LeftTerm,RightTerm],Pos,Ops,IntermediateTerm)
	},
	term_r(Ops,MaxPriority,IntermediateTerm,Priority,Term,TermPriority).
term_r(Ops,MaxPriority,LeftTerm,LeftTermPriority,Term,TermPriority) --> 
	postfix_op(Ops,op(Priority,Associativity,Op),Pos), 
	{	MaxPriority >= Priority, 
		(	Associativity = xf -> 
			Priority > LeftTermPriority 
		; 	% Associativity = yf 
 			Priority >= LeftTermPriority 
		),
		complex_term(Op,[LeftTerm],Pos,Ops,InnerLeftTerm)
	},
	term_r(Ops,MaxPriority,InnerLeftTerm,Priority,Term,TermPriority).
term_r(_Ops,_MaxPriority,T,TP,T,TP) --> [].



prefix_op(ops(PrefixOps,_,_),Op,Pos) --> 
	[a(X,Pos)],
	{ Op=op(_,_,X), memberchk(Op,PrefixOps) }.
	
	
infix_op(ops(_,InfixOps,_),Op,Pos) --> 
	(
		[a(X,Pos)]
	;
		[f(X,Pos)] % ... an infix operator in functor postion; e.g., V=(A,B)
	),
	{ !, Op=op(_,_,X), memberchk(Op,InfixOps) }.


postfix_op(ops(_,_,PostfixOps),Op,Pos) --> 
	[a(X,Pos)],
	{ Op=op(_,_,X), memberchk(Op,PostfixOps) }.



elementary_term(_Ops,V) --> var(V),{!}.
elementary_term(Ops,CT) --> compound_term(Ops,CT),{!}.
elementary_term(Ops,LT) --> list(Ops,LT),{!}.
elementary_term(Ops,T) --> 
	['('(_OPos)],
	term(Ops,1200,T,_TermPriority),
	[')'(_CPos)],
	{!}.
elementary_term(_Ops,chars(Pos,C)) --> [chars(C,Pos)],{!}. % FIXME represent character strings as a list of characters
elementary_term(Ops,te(OPos,T)) --> 
	['{'(OPos)],
	term(Ops,1200,T,_TermPriority),
	['}'(_CPos)],
	{!}. % a term expression (used in combination with DCGs)
elementary_term(_Ops,A) --> atom(A),{!}.



atom(ASTNode) --> [a(A,Pos)],{!,string_atom(A,Pos,ASTNode)}. 
atom(ASTNode) --> [i(I,Pos)],{!,integer_atom(I,Pos,ASTNode)}.
atom(ASTNode) --> [r(F,Pos)],{float_atom(F,Pos,ASTNode)}.



var(ASTNode) --> [v(V,Pos)],{!,variable(V,Pos,ASTNode)}.
var(ASTNode) --> [av(V,Pos)],{anonymous_variable(V,Pos,ASTNode)}.



/*
	HANDLING LISTS

	Lists are represented using their canonical form: ".(Head,Tail)" where
	the Tail is typically either again a list element or the empty list 
	(atom) "[]".
		
	Examples:
	?- [a,b|[]] = .(a,b).
	false.
		
	?- [a,b,c] = .(a,.(b,.(c,[]))).
	true.

	?- [a,b,c|d] = .(a,.(b,.(c,d))).
	true.
*/
list(Ops,ASTNode) --> ['['(Pos)], list_2(Ops,Pos,ASTNode), {!}.


list_2(_Ops,Pos,ASTNode) --> [']'(_Pos)], {!,string_atom([],Pos,ASTNode)}.
list_2(Ops,Pos,ASTNode) --> 
	term(Ops,999,E,_TermPriority),
	list_elements_2(Ops,Es),
	{!,complex_term('.',[E,Es],Pos,ASTNode)}. % we can commit to the current term (E)


list_elements_2(_Ops,ASTNode) --> [']'(Pos)], {!,string_atom([],Pos,ASTNode)}.	
list_elements_2(Ops,ASTNode) --> 
	[a('|',_)], {!},
	term(Ops,1200,ASTNode,_TermPriority),
	[']'(_Pos)],
	{!}. % we can commit to the current term (LE)
list_elements_2(Ops,ASTNode) --> 
	[a(',',Pos)], {!},
	term(Ops,999,E,_TermPriority),
	list_elements_2(Ops,Es),
	{!,complex_term('.',[E,Es],Pos,ASTNode)}. % we can commit to the current term (E)




/*
	HANDLING OF COMPOUND/COMPLEX TERMS
*/
compound_term(Ops,ASTNode) --> 
	[f(F,Pos)],
	['('(_)],
	term(Ops,999,T,_TermPriority), % a complex term has at least one argument
	arguments_2(Ops,TRs),
	{!,complex_term(F,[T|TRs],Pos,ASTNode)}. % we can commit to the current term (T) and the other arguments (TRs)


arguments_2(_Ops,[]) --> [')'(_)],{!}.
arguments_2(Ops,[T|TRs]) --> 
	[a(',',_Pos)],
	term(Ops,999,T,_TermPriority), 
	arguments_2(Ops,TRs),{!}. % we can commit to the term (T) and the arguments (TRs)
	
