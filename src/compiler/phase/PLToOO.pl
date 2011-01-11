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

/*
	Generates the code for the SAE program.

	@author Michael Eichberg
*/
:- module('SAEProlog:Compiler:Phase:PhasePLtoOO',[pl_to_oo/4]).

:- use_module('../AST.pl').
:- use_module('../Predef.pl').
:- use_module('../Utils.pl').
:- use_module('../Debug.pl').
:- use_module('../Analyses.pl').

:- use_module('PLVariableUsageAnalysis.pl',[mapped_variable_ids/2]).


/**
	Encodes an SAE Prolog program using a small object-oriented language (SAEOOL).
	
	This step creates the AST of SAEOOL.
	
	<h1>AST NODES</h1>
	<h2>TOP LEVEL NODES</h2>
	class_decl(PredicateIdentifier,ExtendedClasses,ImplementedInterfaces,ClassMembers) - ClassMembers is a list of SAEOO AST nodes 
	predicate_registration(PredicateIdentifier) - PredicateIdentifier = Functor/Arity

	<h2>CLASS MEMBERS</h2>
	eol_comment(Comment)
	field_decl(goal_stack) - create a field to manage the clause local goal stack(s) (a goal stack is not always required...)
	field_decl(Modifiers,Type,Name)
	field_decl(Modifiers,Type,Name,Expression) - Modifiers is a list of modifiers. Currently, the only allowed/supported modifier is final.)
	constructor_decl(PredicateIdentifier,ParameterDecls,Statements) 
	method_decl(Visibility,ReturnType,Identifier,ParameterDecls,Statements) - Visibility is either public or private

	<h2>STATEMENTS</h2>
	create_undo_goal_and_put_on_goal_stack(TermExpressions) - TermExpressions is a list of expressions where each expression has type term
	clear_goal_stack
	abort_pending_goals_and_clear_goal_stack
	push_onto_goal_stack(GoalExpression)
	remove_top_level_goal_from_goal_stack
	abort_and_remove_top_level_goal_from_goal_stack
	forever(Label,Statements)
	continue(Label)
	eol_comment(Comment)
	switch(SwitchContext,Expression,CaseStatements) - SwitchContext is either "top_level" or "inside_forever"
	expression_statement(Expression)
	manifest_state(ReceiverExpression,Assignee) - ReceiverExpression must be of type "term"
	reincarnate_state(ReceiverExpression) - ReceiverExpression must be of type "state"
	return(Expression)
	local_variable_decl(Type,Name,Expression)
	if(Condition,Statements)
	if(Condition,ThenStatements,ElseStatements)
	error(ErrorDescription) - to signal an programmer's error (e.g., if the developer tries to evaluate a non-arithmetic term.)
	locally_scoped_term_variable(Id,TermExpression)
	
	<h2>EXPRESSIONS</h2>
	get_top_element_from_goal_stack 
	assignment(LValue,Expression)
	method_call(ReceiverExpression,Identifier,Expressions)
	new_object(Type,Expressions) - Expressions is a list of expressions; for each constructor argument an expression has to be given.
	field_ref(Receiver,Identifier)
	local_variable_ref(Identifier)
	reference_comparison(Expression,Expression)
	value_comparison(Operator,LeftExpression,RightExpression) - Comparison of values in the target language
	null
	self - the self reference ("this" in Java)
	string(Value) - a string value in the target language (not a string atom)
	int(Value) - an int value in the target language (not a Prolog int value)
	boolean(Value) - a boolean value in the target language (not a Prolog boolean value)
	unify(Term1Expression,Term2Expression) - base unification without state manifestation
	call_term(TermExpression)
	static_predicate_call(complex_term(Functor,Terms))
	predicate_lookup(Functor,Arity,TermExpressions)
	arithmetic_comparison(Operator,LeftArithmeticTerm,RightArithmeticTerm) - for Prolog terms
	arithmetic_evaluation(ArithmeticTerm) - for Prolog terms
	
	<h2>TERM EXPRESSION</H2>
	string_atom(Value)
	int_value(Value)
	float_value(Value)
	variable
	complex_term(Functor,Terms) - Functor is a string atom and Terms is a list of term expressions (string atoms, int values, float values, variables of compound terms)
	

	<h2>LValue</h2>
	field_ref(Receiver,Identifier)
	local_variable_ref(Identifier)	

	<h2>OTHER</h2>
	param_decl(Type,Name) - Parameters are always considered to be final
	case(ConstantExpression,Statements)
	eol_comment(Comment)
	multiline_comment(Comment)
	
	<h1>TYPES</h1>
	type(void)
	type(int)
	type(boolean)
	type(goal)
	type(goal(PredicateIdentifier))
	type(term)
	type(complex_term)
	type(complex_term(TermIdentifier)) - TermIdentifier = Functor,Arity
	type(atomic(string_atom))
	type(atomic(int_value))
	type(atomic(float_value))
	type(variable) - the type used by Prolog variables
	@param Debug the list of debug information that should be printed.	
*/
pl_to_oo(DebugConfig,Program,_OutputFolder,Program) :-
	debug_message(DebugConfig,on_entry,write('\n[Debug] Phase: Generate the OO Representation_______________________________\n')),
	foreach_user_predicate(Program,process_predicate(DebugConfig,Program)).



process_predicate(DebugConfig,Program,Predicate) :-
	predicate_identifier(Predicate,PredicateIdentifier),
	term_to_atom(PredicateIdentifier,PredicateIdentifierAtom),
	debug_message(DebugConfig,processing_predicate,write_atomic_list(['[Debug] Processing Predicate: ',PredicateIdentifierAtom,'\n'])),
	% build the OO AST
	% METHODS
	SMethods = [SConstructor,SAbortMethod,SChoiceCommittedMethod,SClauseSelectorMethod|S4],
	gen_predicate_constructor(Program,Predicate,SConstructor),
	gen_abort_method(Program,Predicate,SAbortMethod),
	gen_choice_committed_method(Program,Predicate,SChoiceCommittedMethod),
	gen_clause_selector_method(Program,Predicate,SClauseSelectorMethod),
	gen_clause_impl_methods(DeferredActions,Program,Predicate,S4),
	% FIELDS
	gen_fields_for_the_control_flow_and_evaluation_state(DeferredActions,Program,Predicate,S1,S2),
	gen_fields_for_predicate_arguments(Program,Predicate,S2,S3),
	gen_fields_for_clause_local_variables(Predicate,S3,SMethods),
	OOAST = oo_ast([
		class_decl(PredicateIdentifier,type(goal),S1),
		predicate_registration(PredicateIdentifier)
		]),
	predicate_meta(Predicate,Meta),
	add_to_meta(OOAST,Meta).	



/*

	F I E L D S

*/

gen_fields_for_the_control_flow_and_evaluation_state(DeferredActions,_Program,Predicate,SFieldDecls,SR) :-
	predicate_meta(Predicate,PredicateMeta),
	predicate_clauses(Predicate,Clauses),
	% Code to create fields for pre created terms.
	assign_ids_to_pre_created_terms(1,DeferredActions),
	field_decls_for_pre_created_terms(DeferredActions,SFieldDecls,SControlFlow),
	% Standard (instance-related) variables
	SControlFlow = [
		eol_comment('variables to control/manage the execution this predicate')|
		SClauseToExecute
	],
	(	single_clause(Clauses) ->
		SClauseToExecute = SCutEvaluation
	;
		SClauseToExecute = [field_decl([],type(int),'clauseToExecute',int(0))|SCutEvaluation]
	),	
	(	lookup_in_meta(cut(never),PredicateMeta) ->
		SCutEvaluation = SGoalsEvaluation
	;
		SCutEvaluation = [field_decl([],type(boolean),'cutEvaluation',boolean('false'))|SGoalsEvaluation]
	),
	SGoalsEvaluation = [
		field_decl([],type(int),'goalToExecute',int(0)),
		field_decl(goal_stack) |
		SGoalPredescessors
	],
	% For each goal, that is the successor of some "or" goal, we have to create a 
	% a variable that stores which goal was executed previously.
	findall(
		SGoalPredescessor,
		(
			member_ol(create_field_to_store_predecessor_goal(GoalNumber),DeferredActions),
			GoalCaseId is GoalNumber * 2 - 1,
			atomic_list_concat(['goal',GoalCaseId,'PredecessorGoal'],PredecessorGoalFieldIdentifier),
			SGoalPredescessor = field_decl([],type(int),PredecessorGoalFieldIdentifier,int(0))
		),
		SGoalPredescessors,
		SR
	).



gen_fields_for_predicate_arguments(
		_Program,
		Predicate,
		[eol_comment('variables related to the predicate\'s state')|SFieldForArgDecls],
		SR
	) :-
	predicate_identifier(Predicate,PredicateIdentifier),
	PredicateIdentifier = _Functor/Arity,
	(
		lookup_in_predicate_meta(has_clauses_where_last_call_optimization_is_possible,Predicate) ->
		call_foreach_i_in_0_to_u(Arity,field_decl_for_pred_arg_i([]),SFieldForArgDecls,SFieldForArgStateDecls),		
		call_foreach_i_in_0_to_u(Arity,field_decl_for_initial_pred_arg_state_i,SFieldForArgStateDecls,SR)
	;
		call_foreach_i_in_0_to_u(Arity,field_decl_for_pred_arg_i([final]),SFieldForArgDecls,SR)		
	).



field_decl_for_pred_arg_i(Modifiers,I,field_decl(Modifiers,type(term),FieldName)) :-
	atom_concat('arg',I,FieldName). % TODO remove the string concatenation here......just pass the field to the next phase



field_decl_for_initial_pred_arg_state_i(I,field_decl([final],type(state),FieldName)) :-
	atomic_list_concat(['initialArg',I,'state'],FieldName). % TODO remove the string concatenation here...just pass the field to the next phase



gen_fields_for_clause_local_variables(
		Predicate,
		[eol_comment('variables to store clause local information')|SFieldDecls],
		SR
	) :- 
	predicate_meta(Predicate,Meta),
	lookup_in_meta(maximum_number_of_clause_local_variables(Max),Meta),
	call_foreach_i_in_0_to_u(Max,field_decl_for_clause_local_variable,SFieldDecls,SR).



field_decl_for_clause_local_variable(I,field_decl([],type(term),FieldName)) :-
	atom_concat(clv,I,FieldName).



field_decls_for_pre_created_terms(Tail,SR,SR) :- var(Tail),!.
field_decls_for_pre_created_terms(
		[create_field_for_pre_created_term(PCTId,Expr)|Actions],
		SFieldDecl,
		SRest
	) :- !,
	SFieldDecl = [field_decl_for_pre_created_term(PCTId,Expr) | SNextFieldDecl],
	field_decls_for_pre_created_terms(Actions,SNextFieldDecl,SRest).
field_decls_for_pre_created_terms([_Action|Actions],SFieldDecl,SRest) :- 
	field_decls_for_pre_created_terms(Actions,SFieldDecl,SRest).



assign_ids_to_pre_created_terms(_Id,Tail) :- var(Tail),!.
assign_ids_to_pre_created_terms(
		Id,
		[create_field_for_pre_created_term(PCTId,_)|Actions]
	) :-
	(	var(PCTId) ->
		PCTId = Id
	;
		true
	),
	NextId is Id + 1,
	assign_ids_to_pre_created_terms(NextId,Actions).
assign_ids_to_pre_created_terms(Id,[_|Actions]) :-
	assign_ids_to_pre_created_terms(Id,Actions).


/*

	C O N S T R U C T O R
	
*/
gen_predicate_constructor(_Program,Predicate,constructor_decl(PredicateIdentifier,ParamDecls,SInitFieldsForArgsStmts)) :-
	predicate_identifier(Predicate,PredicateIdentifier),
	PredicateIdentifier = _Functor/Arity,
	call_foreach_i_in_0_to_u(Arity,constructor_param_decl_for_arg_i,ParamDecls),
	call_foreach_i_in_0_to_u(Arity,init_field_of_arg_i,SInitFieldsForArgsStmts,SInitFieldsForInitialArgStatesStmts),
	(	lookup_in_predicate_meta(has_clauses_where_last_call_optimization_is_possible,Predicate) ->
		call_foreach_i_in_0_to_u(Arity,init_field_of_initial_arg_state_i,SInitFieldsForInitialArgStatesStmts)	
	;
		SInitFieldsForInitialArgStatesStmts = []
	).
	

constructor_param_decl_for_arg_i(I,param_decl(type(term),ParamName)) :- 
	atom_concat('arg',I,ParamName). % REFACTOR use "arg(I)"
	
	
init_field_of_arg_i(
		I,
		expression_statement(
			assignment(
				field_ref(self,ArgName),expose(
				local_variable_ref(ArgName))))) :-
	atom_concat('arg',I,ArgName).



init_field_of_initial_arg_state_i(
		I,
		manifest_state(
			local_variable_ref(ArgName),
			field_ref(self,FieldName))) :-
	atom_concat('arg',I,ArgName),
	atomic_list_concat(['initialArg',I,'state'],FieldName).



/*

	"void abort()" M E T H O D

*/	
gen_abort_method(_Program,Predicate,AbortMethod) :-
	predicate_identifier(Predicate,_Functor/Arity),
	(	lookup_in_predicate_meta(has_clauses_where_last_call_optimization_is_possible,Predicate) ->
		call_foreach_i_in_0_to_u(Arity,reincarnate_initial_arg_state_i,Stmts,SGoalStack)	
	;
		Stmts = SGoalStack
 	),
	SGoalStack = [abort_pending_goals_and_clear_goal_stack],
	AbortMethod = 
		method_decl(
			public,
			type(void),
			'abort',
			[],
			Stmts).



reincarnate_initial_arg_state_i(
		I,
		reincarnate_state(field_ref(self,FieldName))) :-
	atomic_list_concat(['initialArg',I,'state'],FieldName).



/*

	"boolean choiceCommitted()" M E T H O D

*/	
gen_choice_committed_method(_Program,_Predicate,ChoiceCommittedMethod) :-
	ChoiceCommittedMethod = 
		method_decl(
			public,
			type(boolean),
			'choiceCommitted',
			[],
			[return(boolean(false))]).



/*

	"boolean next()" M E T H O D      ( T H E   C L A U S E   S E L E C T O R )

*/	
gen_clause_selector_method(_Program,Predicate,ClauseSelectorMethod) :-
	predicate_clauses(Predicate,Clauses),
	(	lookup_in_predicate_meta(has_clauses_where_last_call_optimization_is_possible,Predicate) ->
		SMain = [forever('eval_clauses',SEvalGoals)],
		SwitchContext = inside_forever
	;
		SMain = SEvalGoals,
		SwitchContext = top_level
	),
	(	single_clause(Clauses),!,
		SEvalGoals = [return(method_call(self,'clause0',[]))],
		ClauseSelectorMethod = 
			method_decl(
				public,
				type(boolean),
				'next',
				[],
				SMain)
	;	/*
		If we have only two cases it is sufficient to use an "if" statement to 
		branch between these two statements.
		*/
		two_clauses(Clauses),!,
		foreach_clause(
			Clauses,
			selector_for_clause_i(Predicate),
			[
				case(int(0),FirstClauseStmts),
				case(int(1),SecondClauseStmts)
			]
		),
		SEvalGoals = [
			if(
				value_comparison('==',field_ref(self,'clauseToExecute'),int(0)),
				FirstClauseStmts
			)|
			SecondClauseStmts
		],
		ClauseSelectorMethod = 
			method_decl(
				public,
				type(boolean),
				'next',
				[],
				SMain)
	;	/*
		This is the base case to handle arbitrary numbers of clauses.
		*/
		SEvalGoals = [switch(SwitchContext,field_ref(self,'clauseToExecute'),CaseStmts)],
		foreach_clause(Clauses,selector_for_clause_i(Predicate),CaseStmts),
		ClauseSelectorMethod = 
			method_decl(
				public,
				type(boolean),
				'next',
				[],
				SMain)
	).

selector_for_clause_i(_Predicate,I,Clause,last,case(int(I),Stmts)) :- 
	atom_concat('clause',I,ClauseIdentifier),
	lookup_in_clause_meta(last_call_optimization_is_possible,Clause),!,
	reset_clause_local_variables(Clause,SCleanup,SPrepareForNextClause),
	(	lookup_in_clause_meta(cut(never),Clause) ->
		SCutReset = eol_comment('no cut...')
	;
		SCutReset = expression_statement(assignment(field_ref(self,'cutEvaluation'),boolean(false)))
	),
	SPrepareForNextClause = [
		SCutReset,
		expression_statement(assignment(field_ref(self,'goalToExecute'),int(0))),
		expression_statement(assignment(field_ref(self,'clauseToExecute'),int(0))),
		continue('eval_clauses')
	],
	Stmts = [
		eol_comment('tail recursive clause with last call optimization'),
		if(
			method_call(self,ClauseIdentifier,[]),
			SCleanup
		),
		expression_statement(method_call(self,'abort',[])),
		return(boolean(false))
	].

selector_for_clause_i(_Predicate,I,Clause,_ClausePosition,case(int(I),Stmts)) :-
	lookup_in_clause_meta(last_call_optimization_is_possible,Clause),!,
	atom_concat('clause',I,ClauseIdentifier),
	NextClauseId is I + 1,
	(	lookup_in_clause_meta(cut(never),Clause) ->
		SCutReset = eol_comment('no cut...')
	;
		SCutReset = expression_statement(assignment(field_ref(self,'cutEvaluation'),boolean(false)))
	),
	reset_clause_local_variables(
		Clause,
		SResetCLVs,
		[  % after reseting the CLVs...
			SCutReset,		
			expression_statement(assignment(field_ref(self,'goalToExecute'),int(0))),
			expression_statement(assignment(field_ref(self,'clauseToExecute'),int(0))), % unless this is the first clause....
			continue('eval_clauses')
		] 
	),
	(	lookup_in_clause_meta(cut(never),Clause) ->
		SCut = eol_comment('this clause contains no "cut"')
	;
		SCut = if(field_ref(self,'cutEvaluation'),
			[
				expression_statement(method_call(self,'abort',[])),
				return(boolean(false))
			]
		)
	),
	Stmts = [
		if(
			method_call(self,ClauseIdentifier,[]),
			[	eol_comment('tail recursive clause with last call optimization')|
				SResetCLVs
			]
		),		
		SCut,
		eol_comment('prepare the execution of the next clause'),
		expression_statement(assignment(field_ref(self,'goalToExecute'),int(0))),
		expression_statement(assignment(field_ref(self,'clauseToExecute'),int(NextClauseId)))
	].
	

selector_for_clause_i(Predicate,I,_Clause,last,case(int(I),Stmts)) :- !,
	atom_concat('clause',I,ClauseIdentifier),
	% if this is the last clause, we don't care if the evaluation was "cutted" or not
	( lookup_in_predicate_meta(has_clauses_where_last_call_optimization_is_possible,Predicate) ->
		Stmts = [
			if(method_call(self,ClauseIdentifier,[]),
				[return(boolean(true))]
			),
			expression_statement(method_call(self,'abort',[])),
			return(boolean(false))
		]
	;
		Stmts = [return(method_call(self,ClauseIdentifier,[]))]
	).
		
	
selector_for_clause_i(Predicate,I,Clause,_ClausePosition,case(int(I),Stmts)) :-
	atom_concat('clause',I,ClauseIdentifier),
	NextClauseId is I + 1,
	
	reset_clause_local_variables(Clause,SCleanup,SPrepareForNextClause),
	SPrepareForNextClause = [
		eol_comment('prepare the execution of the next clause'),
		expression_statement(assignment(field_ref(self,'goalToExecute'),int(0))),
		expression_statement(assignment(field_ref(self,'clauseToExecute'),int(NextClauseId)))
	],
	(
		lookup_in_clause_meta(cut(never),Clause) ->
		ClauseFailed = [eol_comment('this clause contains no "cut"') |SCleanup]
	;
		(	lookup_in_predicate_meta(has_clauses_where_last_call_optimization_is_possible,Predicate) ->
			Return = [ 
				expression_statement(method_call(self,'abort',[])),
				return(boolean(false))
			]
		;
			Return = [return(boolean(false))]
		),
		ClauseFailed = [
			if(field_ref(self,'cutEvaluation'),
				Return
			) | 
			SCleanup
		]
	),
	Stmts = [
		if(method_call(self,ClauseIdentifier,[]),
			[return(boolean(true))]
		) |
		ClauseFailed
	].



reset_clause_local_variables(
		Clause,
		SCLVReset,
		SR
	) :- 
	lookup_in_clause_meta(clause_local_variables_count(CLVCount),Clause),
	call_foreach_i_in_0_to_u(CLVCount,reset_clause_local_variable,SCLVReset,SR).



reset_clause_local_variable(
		I,
		expression_statement(assignment(field_ref(self,FieldName),null))
	) :-
	atom_concat(clv,I,FieldName). % TODO let the OOto... layer rewrite the names..



/*

	T H E   C L A U S E  I M P L E M E N T A T I O N S
	
	"boolean clauseX()" M E T H O D S      

*/
gen_clause_impl_methods(DeferredActions,_Program,Predicate,ClauseImpls) :-
	predicate_clauses(Predicate,Clauses),
	foreach_clause(Clauses,implementation_for_clause_i(DeferredActions),ClauseImpls).
	
implementation_for_clause_i(DeferredActions,I,Clause,_ClausePosition,ClauseMethod) :-
	atom_concat('clause',I,ClauseIdentifier),
	clause_definition(Clause,ClauseDefinition),
	rule_body(ClauseDefinition,Body),
	number_primitive_goals(Body,0,LastId),
	set_primitive_goals_successors(DeferredActions,Body),
	primitive_goals_list(Body,PrimitiveGoalsList,[]),
	translate_goals(DeferredActions,PrimitiveGoalsList,Cases,[]),
	(	LastId == 1 ->
		MethodBody = [switch(top_level,field_ref(self,'goalToExecute'),Cases)]
	;
		MethodBody = [ 
			forever(
				'eval_goals',
				[switch(inside_forever,field_ref(self,'goalToExecute'),Cases)]
			) 
		]
	),
	ClauseMethod = method_decl(
			private,
			type(boolean),
			ClauseIdentifier,
			[],
			MethodBody
		).



translate_goals(DeferredActions,[PrimitiveGoal|PrimitiveGoals],SGoalCases,SRest) :-
	translate_goal(DeferredActions,PrimitiveGoal,SGoalCases,SOtherGoalCases),
	translate_goals(DeferredActions,PrimitiveGoals,SOtherGoalCases,SRest).
translate_goals(_DeferredActions,[],SCases,SCases).



/**
	To translate a goal, the following information have to be available:
	<ul>
	<li>next_goal_if_fails(Action,GoalNumber)<br />
		Action is either "redo" (in case of backtracking) or "call" (if we try an 
		new alternative)</li>
	<li>next_goal_if_fails(Action,multiple)<br />
		Action must be "redo"</li>
	<li>not_unique_predecessor_goal</li>
	<li>next_goal_if_succeeds(GoalNumber)</li>
	</ul>
*/
translate_goal(_DeferredActions,PrimitiveGoal,[SCall,SRedo|SCases],SCases) :-
	string_atom(PrimitiveGoal,'!'),!,
	term_meta(PrimitiveGoal,Meta),
	lookup_in_meta(goal_number(GoalNumber),Meta),
	% Handle the case if the cut is called the first time
	goal_call_case_id(GoalNumber,CallCaseId),
	select_and_jump_to_next_goal_after_succeed(Meta,force_jump,JumpToNextGoalAfterSucceed),
	SCall = case(
		int(CallCaseId),
		[
			eol_comment('cut...'),
			expression_statement(assignment(field_ref(self,'cutEvaluation'),boolean(true))) |
			JumpToNextGoalAfterSucceed
		]
	),
	% Handle the case if the cut is called the second time (redo-case)
	goal_redo_case_id(GoalNumber,RedoCaseId),
	SRedo = case(
		int(RedoCaseId),
		[
			abort_pending_goals_and_clear_goal_stack,
			return(boolean(false))
		]
	).

/*
	Translates the "unification"
*/

translate_goal(DeferredActions,PrimitiveGoal,[SCallCase,SRedoCase|SCases],SCases) :-
	complex_term(PrimitiveGoal,'=',[LASTNode,RASTNode]),
	(	is_variable(LASTNode), 
		\+ is_variable(RASTNode),
		VarNode = LASTNode,
		TermNode = RASTNode
	;
		is_variable(RASTNode), 
		\+ is_variable(LASTNode),
		VarNode = RASTNode,
		TermNode = LASTNode
	),!,
	term_meta(PrimitiveGoal,UnifyMeta),
	lookup_in_meta(goal_number(GoalNumber),UnifyMeta),
	select_and_jump_to_next_goal_after_succeed(UnifyMeta,force_jump,JumpToNextGoalAfterSucceed),
	select_and_jump_to_next_goal_after_fail(UnifyMeta,JumpToNextGoalAfterFail,[]),
	% call-case
	SHead = [
		locally_scoped_states_list,
		local_variable_decl(type(boolean),'succeeded',boolean(false))
		|
		SUnification
	],
	unfold_unification(DeferredActions,UnifyMeta,VarNode,TermNode,SUnification,STail),	
	STail = [
		if(local_variable_ref('succeeded'),
			[
				create_undo_goal_for_locally_scoped_states_list_and_put_on_goal_stack |
				JumpToNextGoalAfterSucceed
			],
			[
				locally_scoped_states_list_reincarnate_states |
				JumpToNextGoalAfterFail
			]
		)
	],
	goal_call_case_id(GoalNumber,CallCaseId),
	SCallCase = case(
		int(CallCaseId),
		SHead
	),	
	% redo-case
	goal_redo_case_id(GoalNumber,RedoCaseId),
	SRedoCase = case(
		int(RedoCaseId),
		[
			abort_and_remove_top_level_goal_from_goal_stack |
			JumpToNextGoalAfterFail
		]
	).
	

% Handles all other cases of unification 
% IMPROVE unfold the unification of things such as "a(b,X) = a(_,Y)"...
translate_goal(DeferredActions,PrimitiveGoal,[SCallCase,SRedoCase|SCases],SCases) :-
	complex_term(PrimitiveGoal,'=',[LASTNode,RASTNode]),!,
	term_meta(PrimitiveGoal,Meta),
	lookup_in_meta(goal_number(GoalNumber),Meta),
	% call-case
	goal_call_case_id(GoalNumber,CallCaseId),
	select_and_jump_to_next_goal_after_succeed(Meta,force_jump,JumpToNextGoalAfterSucceed),
	create_term(LASTNode,cache,LTermConstructor,LMappedVariableNames,DeferredActions),
	create_term(RASTNode,cache,RTermConstructor,RMappedVariableNames,DeferredActions),
	merge_sets(LMappedVariableNames,RMappedVariableNames,MappedVariableNames),
	SEval = [
		if(unify(LTermConstructor,RTermConstructor),
			JumpToNextGoalAfterSucceed
		)
	],
	(
		lookup_in_meta(variables_used_for_the_first_time(VariablesUsedForTheFirstTime),Meta),
		lookup_in_meta(potentially_used_variables(VariablesPotentiallyPreviouslyUsed),Meta) ->
		init_clause_local_variables(
			VariablesUsedForTheFirstTime,
			VariablesPotentiallyPreviouslyUsed,
			MappedVariableNames,
			SInitCLVs,
			SSaveState
		),
		(	remove_from_set(arg(_),VariablesUsedForTheFirstTime,CLVariablesUsedForTheFirstTime),
			set_subtract(MappedVariableNames,CLVariablesUsedForTheFirstTime,VariablesThatNeedToBeSaved),
			not_empty(VariablesThatNeedToBeSaved) ->
			save_state_in_undo_goal(VariablesThatNeedToBeSaved,SSaveState,SEval),
			RedoAction = [
				abort_and_remove_top_level_goal_from_goal_stack |
				JumpToNextGoalAfterFail
			]
		;
			SSaveState = SEval,
			RedoAction = JumpToNextGoalAfterFail
		)
	;
		%SInitCLVs = SEval
		throw(internal_error(translate_goal/3))
	),
	SCallCase = case(
		int(CallCaseId),
		SInitCLVs
	),
	% redo-case
	goal_redo_case_id(GoalNumber,RedoCaseId),
	select_and_jump_to_next_goal_after_fail(Meta,JumpToNextGoalAfterFail,[]),
	SRedoCase = case(
		int(RedoCaseId),
		RedoAction
	).

/*
	Translates arithmetic comparisons. (e.g., =:=, =<, <, >, ... )
*/
translate_goal(DeferredActions,PrimitiveGoal,[SCallCase,SRedoCase|SCases],SCases) :-
	complex_term(PrimitiveGoal,Operator,[LASTNode,RASTNode]),
	is_arithmetic_comparison_operator(Operator),
	!,
	term_meta(PrimitiveGoal,Meta),% REFACTOR Meta -> PrimitiveGoalMeta
	lookup_in_meta(goal_number(GoalNumber),Meta),
	% call-case...
	goal_call_case_id(GoalNumber,CallCaseId),
	select_and_jump_to_next_goal_after_succeed(
		Meta,
		force_jump,
		JumpToNextGoalAfterSucceed),
	create_term(LASTNode,do_not_cache,LTermConstructor,_LMappedVarIds,DeferredActions),
	create_term(RASTNode,do_not_cache,RTermConstructor,_RMappedVarIds,DeferredActions),
	SCallCase = case(
		int(CallCaseId),
		[
			if(arithmetic_comparison(Operator,LTermConstructor,RTermConstructor),
				JumpToNextGoalAfterSucceed
			)
		]
	),
	% redo-case...
	goal_redo_case_id(GoalNumber,RedoCaseId),
	select_and_jump_to_next_goal_after_fail(Meta,JumpToNextGoalAfterFail,[]),
	SRedoCase = case(
		int(RedoCaseId),
		JumpToNextGoalAfterFail
	).

/*
	Translates the arithmetic evaluation operator "is".
*/
translate_goal(DeferredActions,PrimitiveGoal,[SCall,SRedo|SCases],SCases) :-
	% implements the case that the result of "is" is assigned to a new variable..
	% IMPROVE If the left side of "is" is an int_value or a variable(containing) an int_value, we currently just create an instance of the "is" Predicate, which ist grossly inefficient
	complex_term(PrimitiveGoal,'is',[LASTNode,RASTNode]),
	term_meta(PrimitiveGoal,Meta),
	lookup_in_meta(variables_used_for_the_first_time(NewVariables),Meta),
	lookup_in_term_meta(mapped_variable_name(MVN),LASTNode),
	memberchk_ol(MVN,NewVariables),MVN \= arg(_),!,
	% Handle the case if "is" is called the first time
	lookup_in_meta(goal_number(GoalNumber),Meta),
	goal_call_case_id(GoalNumber,CallCaseId),
	select_and_jump_to_next_goal_after_succeed(Meta,force_jump,JumpToNextGoalAfterSucceed),
	create_term(RASTNode,do_not_cache,RTermConstructor,_RMappedVariableNames,DeferredActions),
	SCall = case(
		int(CallCaseId),
		[
			expression_statement(
				assignment(
					MVN,
					int_value_expr(arithmetic_evluation(RTermConstructor)))) |
			JumpToNextGoalAfterSucceed
		]
	),
	% (redo-case)
	goal_redo_case_id(GoalNumber,RedoCaseId),
	select_and_jump_to_next_goal_after_fail(Meta,JumpToNextGoalAfterFail,[]),
	SRedo = case(
		int(RedoCaseId),
		JumpToNextGoalAfterFail
	).	

/*
	Translates tail recursive calls. (None of the previous goals can be tail-recursive!)
*/
translate_goal(_DeferredActions,PrimitiveGoal,[SGoalCall|SCases],SCases) :-
	term_meta(PrimitiveGoal,Meta),
	lookup_in_meta(last_call_optimization_is_possible,Meta),!,
	lookup_in_meta(goal_number(GoalNumber),Meta),
	goal_call_case_id(GoalNumber,CallCaseId),
	SCaseHead = [eol_comment('tail call with last call optimization')|SLSTVs],
	(	complex_term_args(PrimitiveGoal,Args) ->
		% IMPROVE Identify those variables that were not yet subject to unification..., because for these variables, we can omit calling "expose" (which is nice for all variables that just deal with numbers...)
		lookup_in_meta(variables_used_for_the_first_time(NewVariables),Meta),
		update_predicate_arguments(NewVariables,0,Args,SUpdatePredArgs,SRecursiveCall,IdsOfArgsThatNeedToBeTemporarilySaved),
		findall(
			locally_scoped_term_variable(Id,expose(arg(Id))),
			member_ol(Id,IdsOfArgsThatNeedToBeTemporarilySaved),
			SLSTVs,
			SUpdatePredArgs
		)
	;	% if the predicate does not have arguments... (e.g., repeat)	
		SLSTVs = SRecursiveCall
	),
	SRecursiveCall = [
		clear_goal_stack,
		return(boolean(true))
	],
	SGoalCall = case(
		int(CallCaseId),
		SCaseHead
	).
	
/*
	Translates goals that are neither tail-recursive and subject to last-call
	optimization nor built-ins of the SAE Prolog compiler.
*/
translate_goal(DeferredActions,PrimitiveGoal,[SCallCase,SRedoCase|SCases],SCases) :-
	term_meta(PrimitiveGoal,Meta),
	lookup_in_meta(goal_number(GoalNumber),Meta),
	
	% "call-case"
	goal_call_case_id(GoalNumber,CallCaseId),
	create_term(PrimitiveGoal,do_not_cache_root,TermConstructor,MappedVariableNames,DeferredActions),
	(
		lookup_in_meta(variables_used_for_the_first_time(NewVariables),Meta),
		lookup_in_meta(potentially_used_variables(PotentiallyUsedVariables),Meta) ->
		init_clause_local_variables(
			NewVariables,
			PotentiallyUsedVariables,
			MappedVariableNames,
			SInitCLVs,
			[ push_onto_goal_stack(static_predicate_call(TermConstructor)) ]
		)
	;
		SInitCLVs = [ push_onto_goal_stack(static_predicate_call(TermConstructor)) ]
	),
	SCallCase = case(
		int(CallCaseId),
		SInitCLVs
	),
	
	% "redo-case"
	CallGoal = [
		local_variable_decl(type(boolean),'succeeded',
			method_call(get_top_element_from_goal_stack,'next',[])
		),
		if(not(local_variable_ref('succeeded')),[
			remove_top_level_goal_from_goal_stack |
			JumpToNextGoalAfterFail
		])|
		JumpToNextGoalAfterSucceed
	],
	select_and_jump_to_next_goal_after_fail(Meta,JumpToNextGoalAfterFail,[]),
	select_and_jump_to_next_goal_after_succeed(Meta,may_fall_through,JumpToNextGoalAfterSucceed),
	goal_redo_case_id(GoalNumber,RedoCaseId),
	SRedoCase = case(
		int(RedoCaseId),
		CallGoal
	).



/**
	Generates the code that selects and executes the next goal if this goal
	has failed.
*/
select_and_jump_to_next_goal_after_fail(Meta/*REFACTOR GoalMeta*/,SStmts,SRest) :-
	lookup_in_meta(next_goal_if_fails(redo,multiple),Meta),!,
	lookup_in_meta(goal_number(GoalNumber),Meta),
	goal_call_case_id(GoalNumber,CallCaseId),
	atomic_list_concat(['goal',CallCaseId,'PredecessorGoal'],PredecessorGoal),
	SStmts = [
		expression_statement(assignment(field_ref(self,'goalToExecute'),field_ref(self,PredecessorGoal))),
		continue('eval_goals')
		|SRest
	].
select_and_jump_to_next_goal_after_fail(Meta,SStmts,SRest) :-
	lookup_in_meta(next_goal_if_fails(Action,TargetGoalNumber),Meta),!,
	(	Action == redo ->
		goal_redo_case_id(TargetGoalNumber,TargetCaseId)
	;	% Action == call
		goal_call_case_id(TargetGoalNumber,TargetCaseId)
	),
	SStmts = [
		expression_statement(assignment(field_ref(self,'goalToExecute'),int(TargetCaseId))),
		continue('eval_goals')
		|SRest
	].
% ... if this goal fails, the goal as a whole fails	
select_and_jump_to_next_goal_after_fail(_Meta,[return(boolean(false))|SRest],SRest).



select_and_jump_to_next_goal_after_succeed(Meta,ForceJump,JumpToNextGoalAfterSucceed) :-
	lookup_in_meta(goal_number(GoalNumber),Meta),
	(	lookup_in_meta(next_goal_if_succeeds(TargetGoalNumber),Meta) ->
		goal_call_case_id(TargetGoalNumber,TargetCallCaseId),
		(
			lookup_in_meta(not_unique_predecessor_goal,Meta) ->
			goal_redo_case_id(GoalNumber,ThisGoalRedoCaseId),
			atomic_list_concat(['goal',TargetCallCaseId,'PredecessorGoal'],PredecessorGoal),
			JumpToNextGoalAfterSucceed = [
				expression_statement(assignment(field_ref(self,PredecessorGoal),int(ThisGoalRedoCaseId))) | 
				SelectAndJump
			]
		;
			JumpToNextGoalAfterSucceed = SelectAndJump
		),
		(	TargetGoalNumber =:= GoalNumber + 1, ForceJump \= force_jump  ->
			atom_concat('fall through ... ',TargetCallCaseId,NextGoalIfSucceedComment),
			SelectAndJump = [eol_comment(NextGoalIfSucceedComment)]
		;
			SelectAndJump = [
				expression_statement(assignment(field_ref(self,'goalToExecute'),int(TargetCallCaseId))),
				continue('eval_goals')
			]
		)
	;
		% this is (a) last goal of the clause
		goal_redo_case_id(GoalNumber,ThisGoalRedoCaseId),
		JumpToNextGoalAfterSucceed = [
			expression_statement(assignment(field_ref(self,'goalToExecute'),int(ThisGoalRedoCaseId))),
			return(boolean(true))
		]
	).



/**
	@signature init_clause_local_variables(VariablesUsedForTheFirstTime,VariablesPotentiallyUsedBefore,BodyVariableNames,SInitClauseLocalVariables,SZ).
*/
init_clause_local_variables(
		NewVariables, % REFACTOR these are the VariablesUsedForTheFirstTime
		PotentiallyUsedVariables,
		[MappedBodyVariableName|MappedBodyVariableNames],
		SInitCLV,
		SZ
	) :-
	(	MappedBodyVariableName = clv(_I), % may fail
		(
			memberchk(MappedBodyVariableName,NewVariables),
			term_to_atom(NewVariables,NewVariablesAtom),
			SInitCLV = [
				eol_comment(NewVariablesAtom),
				expression_statement(assignment(MappedBodyVariableName,variable))
				|SI
			]
		;	
			memberchk(MappedBodyVariableName,PotentiallyUsedVariables),
			SInitCLV = [
				if(
					reference_comparison(MappedBodyVariableName,null),
					[
						expression_statement(assignment(MappedBodyVariableName,variable))
					]
				)
				|SI
			]	
		)
	;
		SInitCLV = SI
	),!,
	init_clause_local_variables(NewVariables,PotentiallyUsedVariables,MappedBodyVariableNames,SI,SZ).
init_clause_local_variables(_NewVariables,_PotentiallyUsedVariables,[],SZ,SZ).



save_state_in_undo_goal(MappedVariableNames,SSaveState,SEval) :- 
	SSaveState =[
		create_undo_goal_and_put_on_goal_stack(MappedVariableNames)
		|SEval
	].




/*
	Updates the predicate arguments before the next round (tail recursive)...
	A predicate such as swap(X,Y) :- swap(Y,X) requires that we do store the 
	values of the args.
*/
update_predicate_arguments(_NewVariables,_,[],SR,SR,_) :- !.
update_predicate_arguments(
		NewVariables,
		ArgId,
		[Arg|Args],
		SUpdatePredArg,
		SRest,
		IdsOfArgsThatNeedToBeTemprarilySaved
	) :- % LSTVs are local scoped term variables...
	create_term(Arg,cache,TermConstructor,_,_DeferredActions),
	replace_ids_of_args_lower_than(ArgId,TermConstructor,NewTermConstructor,IdsOfArgsThatNeedToBeTemprarilySaved),
	(	
		NewTermConstructor = expose(arg(ArgId)), memberchk_ol(arg(ArgId),NewVariables),
		!,
		atomic_list_concat(['arg',ArgId,' is not used in the body...'],Comment),
		SUpdatePredArg = [
			eol_comment(Comment)  | 
			SNextUpdatePredArg
		]
	;	
		( NewTermConstructor = arg(_ArgId) ; NewTermConstructor = clv(_CLVId) ),
		!,
		SUpdatePredArg = [
			expression_statement(assignment(arg(ArgId),expose(NewTermConstructor)))  | 
			SNextUpdatePredArg
		]
	;
		SUpdatePredArg = [
			expression_statement(assignment(arg(ArgId),NewTermConstructor)) | 
			SNextUpdatePredArg
		]
	),
	NextArgId is ArgId + 1,
	update_predicate_arguments(NewVariables,NextArgId,Args,SNextUpdatePredArg,SRest,IdsOfArgsThatNeedToBeTemprarilySaved).	



replace_ids_of_args_lower_than(Id,arg(ArgId),NewTermConstructor,Ids) :- 
	!,
	(	ArgId < Id ->
		add_to_set_ol(ArgId,Ids),
		NewTermConstructor = lstv(ArgId)
	;
		NewTermConstructor = expose(arg(ArgId))
	).
replace_ids_of_args_lower_than(_Id,clv(CLVId),NewTermConstructor,_Ids) :- 
	!,
	NewTermConstructor = expose(clv(CLVId)).	
replace_ids_of_args_lower_than(
		Id,
		complex_term(Functor,ArgsConstructors),
		complex_term(Functor,NewArgsConstructors),
		Ids
	) :- !,
	replace_ids_of_args_of_list_lower_than(Id,ArgsConstructors,NewArgsConstructors,Ids).
replace_ids_of_args_lower_than(_Id,TermConstructor,TermConstructor,_).



replace_ids_of_args_of_list_lower_than(_,[],[],_Ids).
replace_ids_of_args_of_list_lower_than(
		Id,
		[ArgConstructor|ArgsConstructors],
		[NewArgConstructor|NewArgsConstructors],
		Ids) :-
	replace_ids_of_args_lower_than(Id,ArgConstructor,NewArgConstructor,Ids),
	replace_ids_of_args_of_list_lower_than(Id,ArgsConstructors,NewArgsConstructors,Ids).



% REFACTOR potentially_used_variables => variables_that_previously_may_have_been_used
unfold_unification(DeferredActions,UnifyMeta,VarNode,TermNode,SUnification,STail) :-
	create_term(VarNode,do_not_cache,VarNodeTermConstructor,[MVN],DeferredActions),
	create_term(TermNode,cache,CachedTermNodeTermConstructor,_,DeferredActions),
	lookup_in_meta(variables_used_for_the_first_time(FTUVars),UnifyMeta), % FTUVars = Firt time used variables
	lookup_in_meta(potentially_used_variables(PPUVars),UnifyMeta), % PPUVars = potentially previously used variables 
	named_variables_of_term(TermNode,NamedVariables,[]),
	mapped_variable_ids(NamedVariables,MappedVariableIds),
	% if the variable is free...
	(	MVN=arg(_), memberchk_ol(MVN,FTUVars) ->
		IsExposed = exposed
	;
		IsExposed = unknown
	),
	init_clause_local_variables(FTUVars,PPUVars,MappedVariableIds,SInitCLVs,SSaveStates),
	SSaveStates = [
		manifest_state_and_add_to_locally_scoped_states_list([MVN]) |
		SSucceeded
	],		
	SSucceeded = [
		bind_variable(MVN,CachedTermNodeTermConstructor),
		expression_statement(assignment(local_variable_ref('succeeded'),boolean(true)))
	],
	% if we can "unfold"...
	create_term(TermNode,do_not_cache_root,TermNodeTermConstructor,_,DeferredActions),
	(
		TermNodeTermConstructor = int_value(_IntValue),!,
		SMatchTerm = [
			if(
				boolean_and(
					test_term_is_integer_value(VarNodeTermConstructor),
					arithmetic_comparison('=:=',VarNodeTermConstructor,TermNodeTermConstructor)
				),
				[
					expression_statement(assignment(local_variable_ref('succeeded'),boolean(true)))
				]
			)
		]
	;
		TermNodeTermConstructor = float_value(_FloatValue),!,
		SMatchTerm = [
			if(
				boolean_and(
					test_term_is_float_value(VarNodeTermConstructor),
					arithmetic_comparison('=:=',VarNodeTermConstructor,TermNodeTermConstructor)
				),
				[
					expression_statement(assignment(local_variable_ref('succeeded'),boolean(true)))
				]
			)
		]
	;
		TermNodeTermConstructor = string_atom(_StringAtom),!,
		SMatchTerm = [
			if(
				boolean_and(
					test_term_is_string_atom(VarNodeTermConstructor),
					string_atom_comparison(VarNodeTermConstructor,TermNodeTermConstructor)
				),
				[
					expression_statement(assignment(local_variable_ref('succeeded'),boolean(true)))
				]
			)
		]
	;
		TermNodeTermConstructor = complex_term(FunctorConstructor,ArgsConstructors),!,
		FunctorConstructor = string_atom(StringValue),
		create_term_for_cacheable_string_atom(
				StringValue,
				CachedFunctorConstructor,
				DeferredActions),
		length(ArgsConstructors,ArgsConstructorsCount),
		lookup_in_meta(variables_used_for_the_first_time(VariablesUsedForTheFirstTime),UnifyMeta),
		remove_from_set(arg(_),VariablesUsedForTheFirstTime,CLVariablesUsedForTheFirstTime),
		test_and_unify_args(
			ArgsConstructors,
			MVN,
			0,
			[],CLVariablesUsedForTheFirstTime,
			STest,
			[ expression_statement(assignment(local_variable_ref('succeeded'),boolean(true))) ],
			DeferredActions),
		SMatchTerm = [
			if(
				boolean_and(
					value_comparison('==',term_arity(VarNodeTermConstructor),int(ArgsConstructorsCount)),					
					functor_comparison(term_functor(VarNodeTermConstructor),CachedFunctorConstructor)
				),
				STest
			)		
		]
	),
	SUnification = [
		if(test_rttype_of_term_is_free_variable(IsExposed,VarNodeTermConstructor),
			SInitCLVs,
			SMatchTerm
		) |
		STail
	].


% GOAL Locally used variables..
test_and_unify_args(
		[],
		_BaseVariable,_ArgId,_VarsWithSavedState,_VarsThatAreFree,
		SRest,SRest,
		_DeferredActions).
test_and_unify_args(
		[ArgsConstructor|ArgsConstructors],
		BaseVariable,
		ArgId,
		VarsWithSavedState,VarsThatAreFree,
		STaU,SRest,
		DeferredActions
	) :- 
	ArgsConstructor = clv(_),
	memberchk(ArgsConstructor,VarsThatAreFree),!,
	STaU = [
		expression_statement(assignment(ArgsConstructor,term_arg(BaseVariable,int(ArgId))))
		| SFurtherTaU
	],	
	remove_from_set(ArgId,VarsThatAreFree,NewVarsThatAreFree),
	NewArgId is ArgId + 1,
	test_and_unify_args(
		ArgsConstructors,
		BaseVariable,
		NewArgId,
		VarsWithSavedState,NewVarsThatAreFree,
		SFurtherTaU,SRest,
		DeferredActions). 
test_and_unify_args(
		[ArgsConstructor|ArgsConstructors],
		BaseVariable,
		ArgId,
		VarsWithSavedState,VarsThatAreFree,
		STaU,SRest,
		DeferredActions	
	) :- 
	ArgsConstructor = anonymous_variable,!,
	NewArgId is ArgId + 1,
	test_and_unify_args(
		ArgsConstructors,
		BaseVariable,
		NewArgId,
		VarsWithSavedState,VarsThatAreFree,
		STaU,SRest,
		DeferredActions).
% the base case... 
test_and_unify_args(
		[ArgsConstructor|ArgsConstructors],
		BaseVariable,
		ArgId,
		VarsWithSavedState,
		VarsThatAreFree,
		STaU,SRest,
		DeferredActions) :- 
	term_constructor_variables(ArgsConstructor,UsedVariables,[]),	
	set_subtract(UsedVariables,VarsWithSavedState,UsedVarsWithNoSavedState),
	set_subtract(UsedVarsWithNoSavedState,VarsThatAreFree,VarsThatNeedToBeSaved),
	% init goal local variables that are not yet initialized
	intersect_sets(VarsThatAreFree,UsedVariables,VarsThatNeedToBeInitialized),
	findall(
		InitStmt,
		(
			member(Var,VarsThatNeedToBeInitialized),
			InitStmt = if(
				reference_comparison(Var,null),
				[
					expression_statement(assignment(Var,variable))
				]
			)
		),
		STaU,
		SSaveStatesAndUnify
	),
	SSaveStatesAndUnify = [
		% save the state of the nth argument of the base variable and the vars that need to be saved
		manifest_state_and_add_to_locally_scoped_states_list(
			[term_arg(BaseVariable,int(ArgId))|VarsThatNeedToBeSaved]
		),
		if(unify(term_arg(BaseVariable,int(ArgId)),ArgsConstructor),
		 	SFurtherTaU
		)
	],
	merge_sets(VarsWithSavedState,VarsThatNeedToBeSaved,NewVarsWithSavedState),
	set_subtract(VarsThatAreFree,VarsThatNeedToBeInitialized,NewVarsThatAreFree),
	NewArgId is ArgId + 1,
	test_and_unify_args(
		ArgsConstructors,
		BaseVariable,
		NewArgId,
		NewVarsWithSavedState,
		NewVarsThatAreFree,
		SFurtherTaU,SRest,
		DeferredActions).



term_constructor_variables(int_value(_),SRest,SRest) :- !.
term_constructor_variables(float_value(_),SRest,SRest) :- !.
term_constructor_variables(string_atom(_),SRest,SRest) :- !.
term_constructor_variables(pre_created_term(_),SRest,SRest) :- !.
term_constructor_variables(anonymous_variable,SRest,SRest) :- !.
term_constructor_variables(complex_term(_,Args),SMappedVariables,SRest) :- !,
	term_constructors_mapped_variables(Args,SMappedVariables,SRest).
term_constructor_variables(Variable,[Variable|SRest],SRest) :- !.


term_constructors_mapped_variables([],SRest,SRest).
term_constructors_mapped_variables([Arg|Args],SMappedVariables,SRest) :-
	term_constructor_variables(Arg,SMappedVariables,SIMappedVariables),
	term_constructors_mapped_variables(Args,SIMappedVariables,SRest).



/**
	@signature create_term(ASTNode,Type,TermConstructor,MappedVariableNames,DeferredActions)
	@arg(in) Type is either "cache", "do_not_cache_root" or "do_not_cache"
	@arg(out) MappedVariableNames - the names of the variables used by this term
*/
create_term(
		ASTNode,
		_Type,_TermConstructor,_MappedVariableNames,_DeferredActions
	) :- % let's catch some programming errors early on...
	var(ASTNode),!,throw(internal_error(create_term/5,'ASTNode needs to be instantiated')).
create_term(ASTNode,Type,TermConstructor,MappedVariableNames,DeferredActions) :-
	create_term(ASTNode,Type,TermConstructor,[],MappedVariableNames,DeferredActions).

/**
	@signature create_term(ASTNode,Type,TermConstructor,OldVariables,NewVariables,DeferredActions)
*/
create_term(ASTNode,_Type,int_value(Value),MVNs,MVNs,_DeferredActions) :-	
	integer_atom(ASTNode,Value),!.
create_term(ASTNode,_Type,float_value(Value),MVNs,MVNs,_DeferredActions) :-
	float_atom(ASTNode,Value),!.

create_term(ASTNode,do_not_cache,string_atom(Value),MVNs,MVNs,_DeferredActions) :- 	
	string_atom(ASTNode,Value),!.
create_term(ASTNode,do_not_cache_root,string_atom(Value),MVNs,MVNs,_DeferredActions) :- 	
	string_atom(ASTNode,Value),!.	
create_term(ASTNode,cache,TermConstructor,MVNs,MVNs,DeferredActions) :- 	
	string_atom(ASTNode,Value),!,
	create_term_for_cacheable_string_atom(Value,TermConstructor,DeferredActions).

create_term(ASTNode,do_not_cache,complex_term(string_atom(Functor),ArgsConstructors),OldMVNs,NewMVNs,DeferredActions) :-
	complex_term(ASTNode,Functor,Args),
	create_terms(Args,do_not_cache,ArgsConstructors,OldMVNs,NewMVNs,DeferredActions),!.
create_term(ASTNode,do_not_cache_root,complex_term(string_atom(Functor),ArgsConstructors),OldMVNs,NewMVNs,DeferredActions) :-
	complex_term(ASTNode,Functor,Args),
	create_terms(Args,cache,ArgsConstructors,OldMVNs,NewMVNs,DeferredActions),!.
create_term(ASTNode,cache,TermConstructor,OldMVNs,NewMVNs,DeferredActions) :-
	complex_term(ASTNode,Functor,Args),
	create_term_for_cacheable_string_atom(Functor,FunctorConstructor,DeferredActions),
	TC = complex_term(FunctorConstructor,ArgsConstructors),
	(	is_ground_term(ASTNode) ->
		create_terms(Args,do_not_cache,ArgsConstructors,OldMVNs,NewMVNs,DeferredActions),
		TermConstructor = pre_created_term(CTId),
		add_to_set_ol(create_field_for_pre_created_term(CTId,TC),DeferredActions)
	;
		create_terms(Args,cache,ArgsConstructors,OldMVNs,NewMVNs,DeferredActions),
		TermConstructor = TC
	),!.

create_term(ASTNode,_,anonymous_variable,MVNs,MVNs,_DeferredActions) :- 
	anonymous_variable(ASTNode,_VariableName),!.	

create_term(ASTNode,_Type,MappedVariableName,OldMVNs,NewMVNs,_DeferredActions) :- 
	is_variable(ASTNode),!,
	term_meta(ASTNode,Meta),
	lookup_in_meta(mapped_variable_name(MappedVariableName),Meta),
	add_to_set(MappedVariableName,OldMVNs,NewMVNs).	

create_term(ASTNode,Type,_,_,_,_) :-
	throw(internal_error(create_term/6,['the ASTNode (',ASTNode,') has an unknown type(',Type,')'])).



create_terms([Arg|Args],Type,[TermConstructor|TermConstructors],OldMVNs,NewMVNs,DeferredActions) :- !,
	create_term(Arg,Type,TermConstructor,OldMVNs,IMVNs,DeferredActions),
	create_terms(Args,Type,TermConstructors,IMVNs,NewMVNs,DeferredActions).
create_terms([],_Type,[],MVNs,MVNs,_DeferredActions).



create_term_for_cacheable_string_atom(
		StringValue,
		TermConstructor,
		DeferredActions
	) :- 
	(
		predefined_functor(StringValue) ->
		TermConstructor = string_atom(StringValue)
	;	
		TermConstructor = pre_created_term(Id),
		add_to_set_ol(
			create_field_for_pre_created_term(Id,string_atom(StringValue)),
			DeferredActions)
	).



/* *************************************************************************** *\

	HELPER METHODS TO DETERMINE THE CONTROL FLOW

\* *************************************************************************** */



/**
	Returns the list of all primitive goals of the given term.<br />
	The first element of the list is always the primitive goal that would be 
	executed first, if we would call the term as a whole.

	@signature primitive_goals_list(ASTNode,SGoals_HeadOfListOfASTNodes,SRest_TailOfThePreviousList)
*/
primitive_goals_list(ASTNode,SGoal,SGoals) :- 
	complex_term(ASTNode,Functor,[LASTNode,RASTNode]),
	(	
		Functor = ',' 
	; 
		Functor = ';' 
	),
	!,
	primitive_goals_list(LASTNode,SGoal,SFurtherGoals),
	primitive_goals_list(RASTNode,SFurtherGoals,SGoals).
primitive_goals_list(ASTNode,[ASTNode|SGoals],SGoals).



/**
	Associates each primitive goal with a unique number; the information
	is added to a goal's meta information.

	Typical usage: <code>number_primitive_goals(ASTNode,0,L)</code>
*/
number_primitive_goals(ASTNode,First,Last) :-
	complex_term(ASTNode,Functor,[LASTNode,RASTNode]),
	(	
		Functor = ','
	; 
		Functor = ';' 
	),
	!,
	number_primitive_goals(LASTNode,First,Intermediate),
	number_primitive_goals(RASTNode,Intermediate,Last).
number_primitive_goals(ASTNode,First,Last) :-
	term_meta(ASTNode,Meta),
	add_to_meta(goal_number(First),Meta),
	Last is First + 1.



/**
	Adds the following meta-information to each (primitive) goal:
	<ul>
	<li>next_goal_if_fails(GoalNumber)</li>
	<li>next_goal_if_fails(multiple)</li>
	<li>not_unique_predecessor_goal</li>
	<li>next_goal_if_succeeds(GoalNumber)</li>
	</ul>
	Prerequisite: all primitive goals must be numbered.<br />
*/
set_primitive_goals_successors(DeferredActions,ASTNode) :-
	complex_term(ASTNode,',',[LASTNode,RASTNode]),!,
	first_primitive_goal(RASTNode,FR),
	last_primitive_goals_if_true(LASTNode,LeftLPGTs,[]),
	last_primitive_goal_if_false(RASTNode,RightLPGF),
	set_successors(DeferredActions,LeftLPGTs,succeeds,[FR]),
	set_successors(DeferredActions,[RightLPGF],fails(redo),LeftLPGTs),
	set_primitive_goals_successors(DeferredActions,LASTNode),
	set_primitive_goals_successors(DeferredActions,RASTNode).
set_primitive_goals_successors(DeferredActions,ASTNode) :-
	complex_term(ASTNode,';',[LASTNode,RASTNode]),!,
	first_primitive_goal(RASTNode,FR),
	first_primitive_goal(LASTNode,FL),
	set_successors(DeferredActions,[FL],fails(call),[FR]),
	set_primitive_goals_successors(DeferredActions,LASTNode),
	set_primitive_goals_successors(DeferredActions,RASTNode).	
set_primitive_goals_successors(_DeferredActions,_ASTNode).



set_successors(DeferredActions,[ASTNode|ASTNodes],Type,SuccessorASTNodes) :-
	set_successor(DeferredActions,ASTNode,Type,SuccessorASTNodes),
	set_successors(DeferredActions,ASTNodes,Type,SuccessorASTNodes).
set_successors(_DeferredActions,[],_Type,_SuccessorASTNodes).



set_successor(DeferredActions,ASTNode,succeeds,[SuccessorASTNode|SuccessorASTNodes]) :-
	set_succeeds_successor(ASTNode,SuccessorASTNode),
	set_successor(DeferredActions,ASTNode,succeeds,SuccessorASTNodes).
set_successor(_DeferredActions,_ASTNode,succeeds,[]).
% Action is either "call" or "redo"
set_successor(DeferredActions,ASTNode,fails(Action),SuccessorASTNodes) :-
	term_meta(ASTNode,Meta),
	(
		SuccessorASTNodes = [SuccessorASTNode], % ... may fail
		term_meta(SuccessorASTNode,SuccessorMeta),
		lookup_in_meta(goal_number(GoalNumber),SuccessorMeta),
		add_to_meta(next_goal_if_fails(Action,GoalNumber),Meta)
	;
		lookup_in_meta(goal_number(GoalNumber),Meta),
		add_to_set_ol(create_field_to_store_predecessor_goal(GoalNumber),DeferredActions),
		add_to_meta(next_goal_if_fails(Action,multiple),Meta),
		add_to_each_term_meta(not_unique_predecessor_goal,SuccessorASTNodes)
	),!.



set_succeeds_successor(ASTNode,SuccessorASTNode) :-
	term_meta(ASTNode,Meta),
	term_meta(SuccessorASTNode,SuccessorMeta),
	lookup_in_meta(goal_number(GoalNumber),SuccessorMeta),
	add_to_meta(next_goal_if_succeeds(GoalNumber),Meta).



goal_call_case_id(GoalNumber,CallCaseId) :-
	CallCaseId is GoalNumber * 2.



goal_redo_case_id(GoalNumber,RedoCaseId) :-
	RedoCaseId is GoalNumber * 2 + 1.


