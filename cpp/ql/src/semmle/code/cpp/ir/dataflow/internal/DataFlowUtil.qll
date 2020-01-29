/**
 * Provides C++-specific definitions for use in the data flow library.
 */

private import cpp
private import semmle.code.cpp.ir.IR
private import semmle.code.cpp.controlflow.IRGuards
private import semmle.code.cpp.ir.ValueNumbering

/**
 * A newtype wrapper to prevent accidental casts between `Node` and
 * `Instruction`. This ensures we can add `Node`s that are not `Instruction`s
 * in the future.
 */
private newtype TIRDataFlowNode = MkIRDataFlowNode(Instruction i)

/**
 * A node in a data flow graph.
 *
 * A node can be either an expression, a parameter, or an uninitialized local
 * variable. Such nodes are created with `DataFlow::exprNode`,
 * `DataFlow::parameterNode`, and `DataFlow::uninitializedNode` respectively.
 */
class Node extends TIRDataFlowNode {
  Instruction instr;

  Node() { this = MkIRDataFlowNode(instr) }

  /**
   * INTERNAL: Do not use. Alternative name for `getFunction`.
   */
  Function getEnclosingCallable() { result = this.getFunction() }

  Function getFunction() { result = instr.getEnclosingFunction() }

  /** Gets the type of this node. */
  Type getType() { result = instr.getResultType() }

  Instruction asInstruction() { this = MkIRDataFlowNode(result) }

  /**
   * Gets the non-conversion expression corresponding to this node, if any. If
   * this node strictly (in the sense of `asConvertedExpr`) corresponds to a
   * `Conversion`, then the result is that `Conversion`'s non-`Conversion` base
   * expression.
   */
  Expr asExpr() {
    result.getConversion*() = instr.getConvertedResultExpression() and
    not result instanceof Conversion
  }

  /**
   * Gets the expression corresponding to this node, if any. The returned
   * expression may be a `Conversion`.
   */
  Expr asConvertedExpr() { result = instr.getConvertedResultExpression() }

  /** Gets the argument that defines this `DefinitionByReferenceNode`, if any. */
  Expr asDefiningArgument() { result = this.(DefinitionByReferenceNode).getArgument() }

  /** Gets the parameter corresponding to this node, if any. */
  Parameter asParameter() { result = instr.(InitializeParameterInstruction).getParameter() }

  /**
   * DEPRECATED: See UninitializedNode.
   *
   * Gets the uninitialized local variable corresponding to this node, if
   * any.
   */
  LocalVariable asUninitialized() { none() }

  /**
   * Gets an upper bound on the type of this node.
   */
  Type getTypeBound() { result = getType() }

  /** Gets the location of this element. */
  Location getLocation() { result = instr.getLocation() }

  /**
   * Holds if this element is at the specified location.
   * The location spans column `startcolumn` of line `startline` to
   * column `endcolumn` of line `endline` in file `filepath`.
   * For more information, see
   * [Locations](https://help.semmle.com/QL/learn-ql/ql/locations.html).
   */
  predicate hasLocationInfo(
    string filepath, int startline, int startcolumn, int endline, int endcolumn
  ) {
    this.getLocation().hasLocationInfo(filepath, startline, startcolumn, endline, endcolumn)
  }

  string toString() {
    // This predicate is overridden in subclasses. This default implementation
    // does not use `Instruction.toString` because that's expensive to compute.
    result = this.asInstruction().getOpcode().toString()
  }
}

/**
 * An expression, viewed as a node in a data flow graph.
 */
class ExprNode extends Node {
  ExprNode() { exists(this.asExpr()) }

  /**
   * Gets the non-conversion expression corresponding to this node, if any. If
   * this node strictly (in the sense of `getConvertedExpr`) corresponds to a
   * `Conversion`, then the result is that `Conversion`'s non-`Conversion` base
   * expression.
   */
  Expr getExpr() { result = this.asExpr() }

  /**
   * Gets the expression corresponding to this node, if any. The returned
   * expression may be a `Conversion`.
   */
  Expr getConvertedExpr() { result = this.asConvertedExpr() }

  override string toString() { result = this.asConvertedExpr().toString() }
}

/**
 * The value of a parameter at function entry, viewed as a node in a data
 * flow graph.
 */
class ParameterNode extends Node {
  override InitializeParameterInstruction instr;

  /**
   * Holds if this node is the parameter of `c` at the specified (zero-based)
   * position. The implicit `this` parameter is considered to have index `-1`.
   */
  predicate isParameterOf(Function f, int i) { f.getParameter(i) = instr.getParameter() }

  Parameter getParameter() { result = instr.getParameter() }

  override string toString() { result = instr.getParameter().toString() }
}

private class ThisParameterNode extends Node {
  override InitializeThisInstruction instr;

  override string toString() { result = "this" }
}

/**
 * DEPRECATED: Data flow was never an accurate way to determine what
 * expressions might be uninitialized. It errs on the side of saying that
 * everything is uninitialized, and this is even worse in the IR because the IR
 * doesn't use syntactic hints to rule out variables that are definitely
 * initialized.
 *
 * The value of an uninitialized local variable, viewed as a node in a data
 * flow graph.
 */
deprecated class UninitializedNode extends Node {
  UninitializedNode() { none() }

  LocalVariable getLocalVariable() { none() }
}

/**
 * A node associated with an object after an operation that might have
 * changed its state.
 *
 * This can be either the argument to a callable after the callable returns
 * (which might have mutated the argument), or the qualifier of a field after
 * an update to the field.
 *
 * Nodes corresponding to AST elements, for example `ExprNode`, usually refer
 * to the value before the update with the exception of `ClassInstanceExpr`,
 * which represents the value after the constructor has run.
 *
 * This class exists to match the interface used by Java. There are currently no non-abstract
 * classes that extend it. When we implement field flow, we can revisit this.
 */
abstract class PostUpdateNode extends Node {
  /**
   * Gets the node before the state update.
   */
  abstract Node getPreUpdateNode();
}

/**
 * A node that represents the value of a variable after a function call that
 * may have changed the variable because it's passed by reference.
 *
 * A typical example would be a call `f(&x)`. Firstly, there will be flow into
 * `x` from previous definitions of `x`. Secondly, there will be a
 * `DefinitionByReferenceNode` to represent the value of `x` after the call has
 * returned. This node will have its `getArgument()` equal to `&x` and its
 * `getVariableAccess()` equal to `x`.
 */
class DefinitionByReferenceNode extends Node {
  override WriteSideEffectInstruction instr;

  /** Gets the argument corresponding to this node. */
  Expr getArgument() {
    result = instr
          .getPrimaryInstruction()
          .(CallInstruction)
          .getPositionalArgument(instr.getIndex())
          .getUnconvertedResultExpression()
    or
    result = instr
          .getPrimaryInstruction()
          .(CallInstruction)
          .getThisArgument()
          .getUnconvertedResultExpression() and
    instr.getIndex() = -1
  }

  /** Gets the parameter through which this value is assigned. */
  Parameter getParameter() {
    exists(CallInstruction ci | result = ci.getStaticCallTarget().getParameter(instr.getIndex()))
  }
}

/**
 * Gets the node corresponding to `instr`.
 */
Node instructionNode(Instruction instr) { result.asInstruction() = instr }

DefinitionByReferenceNode definitionByReferenceNode(Expr e) { result.getArgument() = e }

/**
 * Gets a `Node` corresponding to `e` or any of its conversions. There is no
 * result if `e` is a `Conversion`.
 */
ExprNode exprNode(Expr e) { result.getExpr() = e }

/**
 * Gets the `Node` corresponding to `e`, if any. Here, `e` may be a
 * `Conversion`.
 */
ExprNode convertedExprNode(Expr e) { result.getExpr() = e }

/**
 * Gets the `Node` corresponding to the value of `p` at function entry.
 */
ParameterNode parameterNode(Parameter p) { result.getParameter() = p }

/**
 * Gets the `Node` corresponding to the value of an uninitialized local
 * variable `v`.
 */
UninitializedNode uninitializedNode(LocalVariable v) { result.getLocalVariable() = v }

/**
 * Holds if data flows from `nodeFrom` to `nodeTo` in exactly one local
 * (intra-procedural) step.
 */
predicate localFlowStep(Node nodeFrom, Node nodeTo) { simpleLocalFlowStep(nodeFrom, nodeTo) }

/**
 * INTERNAL: do not use.
 *
 * This is the local flow predicate that's used as a building block in global
 * data flow. It may have less flow than the `localFlowStep` predicate.
 */
predicate simpleLocalFlowStep(Node nodeFrom, Node nodeTo) {
  simpleInstructionLocalFlowStep(nodeFrom.asInstruction(), nodeTo.asInstruction())
}

private predicate simpleInstructionLocalFlowStep(Instruction iFrom, Instruction iTo) {
  iTo.(CopyInstruction).getSourceValue() = iFrom
  or
  iTo.(PhiInstruction).getAnOperand().getDef() = iFrom
  or
  // Treat all conversions as flow, even conversions between different numeric types.
  iTo.(ConvertInstruction).getUnary() = iFrom
  or
  iTo.(CheckedConvertOrNullInstruction).getUnary() = iFrom
  or
  iTo.(InheritanceConversionInstruction).getUnary() = iFrom
  or
  // A chi instruction represents a point where a new value (the _partial_
  // operand) may overwrite an old value (the _total_ operand), but the alias
  // analysis couldn't determine that it surely will overwrite every bit of it or
  // that it surely will overwrite no bit of it.
  //
  // By allowing flow through the total operand, we ensure that flow is not lost
  // due to shortcomings of the alias analysis. We may get false flow in cases
  // where the data is indeed overwritten.
  iTo.getAnOperand().(ChiTotalOperand).getDef() = iFrom
  or
  // Flow through the partial operand must be restricted a bit more. For
  // soundness, the IR has to assume that every write to an unknown address can
  // affect every escaped variable, and this assumption shows up as data flowing
  // through partial chi operands. The chi instructions for all escaped data can
  // be recognized by having unknown types. For all other chi instructions, flow
  // through partial operands is more likely to be real.
  exists(ChiInstruction chi | iTo = chi |
    iFrom = chi.getPartial() and
    not chi.getResultIRType() instanceof IRUnknownType
  )
}

/**
 * Holds if data flows from `source` to `sink` in zero or more local
 * (intra-procedural) steps.
 */
predicate localFlow(Node source, Node sink) { localFlowStep*(source, sink) }

/**
 * Holds if data can flow from `i1` to `i2` in zero or more
 * local (intra-procedural) steps.
 */
predicate localInstructionFlow(Instruction e1, Instruction e2) {
  localFlow(instructionNode(e1), instructionNode(e2))
}

/**
 * Holds if data can flow from `e1` to `e2` in zero or more
 * local (intra-procedural) steps.
 */
predicate localExprFlow(Expr e1, Expr e2) { localFlow(exprNode(e1), exprNode(e2)) }

/**
 * A guard that validates some instruction.
 *
 * To use this in a configuration, extend the class and provide a
 * characteristic predicate precisely specifying the guard, and override
 * `checks` to specify what is being validated and in which branch.
 *
 * It is important that all extending classes in scope are disjoint.
 */
class BarrierGuard extends IRGuardCondition {
  /** Override this predicate to hold if this guard validates `instr` upon evaluating to `b`. */
  abstract predicate checks(Instruction instr, boolean b);

  /** Gets a node guarded by this guard. */
  final Node getAGuardedNode() {
    exists(ValueNumber value, boolean edge |
      result.asInstruction() = value.getAnInstruction() and
      this.checks(value.getAnInstruction(), edge) and
      this.controls(result.asInstruction().getBlock(), edge)
    )
  }
}
