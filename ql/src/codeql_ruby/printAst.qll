/**
 * Provides queries to pretty-print a Ruby abstract syntax tree as a graph.
 *
 * By default, this will print the AST for all nodes in the database. To change
 * this behavior, extend `PrintASTConfiguration` and override `shouldPrintNode`
 * to hold for only the AST nodes you wish to view.
 */

import AST

/** Holds if `n` appears in the desugaring of some other node. */
predicate isDesugared(AstNode n) {
  n = any(AstNode sugar).getDesugared()
  or
  isDesugared(n.getParent())
}

/**
 * The query can extend this class to control which nodes are printed.
 */
class PrintAstConfiguration extends string {
  PrintAstConfiguration() { this = "PrintAstConfiguration" }

  /**
   * Holds if the given node should be printed.
   */
  predicate shouldPrintNode(AstNode n) {
    not isDesugared(n)
    or
    not n.isSynthesized()
    or
    n.isSynthesized() and
    not n = any(AstNode sugar).getDesugared() and
    exists(AstNode parent |
      parent = n.getParent() and
      not parent.isSynthesized() and
      not n = parent.getDesugared()
    )
  }
}

/**
 * A node in the output tree.
 */
class PrintAstNode extends AstNode {
  string getProperty(string key) {
    key = "semmle.label" and
    result = "[" + concat(this.getAPrimaryQlClass(), ", ") + "] " + this.toString()
    or
    key = "semmle.order" and
    result =
      any(int i |
        this =
          rank[i](AstNode p, Location l, File f |
            l = p.getLocation() and
            f = l.getFile()
          |
            p order by f.getBaseName(), f.getAbsolutePath(), l.getStartLine(), l.getStartColumn()
          )
      ).toString()
  }

  /**
   * Holds if this node should be printed in the output. By default, all nodes
   * are printed, but the query can override
   * `PrintAstConfiguration.shouldPrintNode` to filter the output.
   */
  predicate shouldPrint() { shouldPrintNode(this) }

  /**
   * Gets the child node that is accessed using the predicate `edgeName`.
   */
  PrintAstNode getChild(string edgeName) { result = this.getAChild(edgeName) }
}

private predicate shouldPrintNode(AstNode n) {
  exists(PrintAstConfiguration config | config.shouldPrintNode(n))
}

/**
 * Holds if `node` belongs to the output tree, and its property `key` has the
 * given `value`.
 */
query predicate nodes(PrintAstNode node, string key, string value) {
  node.shouldPrint() and
  value = node.getProperty(key)
}

/**
 * Holds if `target` is a child of `source` in the AST, and property `key` of
 * the edge has the given `value`.
 */
query predicate edges(PrintAstNode source, PrintAstNode target, string key, string value) {
  source.shouldPrint() and
  target.shouldPrint() and
  target = source.getChild(_) and
  (
    key = "semmle.label" and
    value = strictconcat(string name | source.getChild(name) = target | name, "/")
    or
    key = "semmle.order" and
    value = target.getProperty("semmle.order")
  )
}

/**
 * Holds if property `key` of the graph has the given `value`.
 */
query predicate graphProperties(string key, string value) {
  key = "semmle.graphKind" and value = "tree"
}
