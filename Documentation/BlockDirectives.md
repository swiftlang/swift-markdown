# Block Directives

Block directives are a syntax extension that create attributed containers to hold other block elements, such as paragraphs and lists, or even other block directives. Here is what one looks like:

```markdown
@Directive(x: 1, y: 2
           z: 3) {
    - A
    - B
    - C
}
```

This creates a syntax tree that looks like this:

```
Document
└─ BlockDirective name: "Directive"
   ├─ Argument text segments:
   |    "x: 1, y: 2"
   |    "           z: 3"
   └─ UnorderedList
      ├─ ListItem
      │  └─ Paragraph
      │     └─ Text "A"
      ├─ ListItem
      │  └─ Paragraph
      │     └─ Text "B"
      └─ ListItem
         └─ Paragraph
            └─ Text "C"
```

There are three main pieces to a block directive: the name, the argument text, and its content.

## Names

Block directives are opened with an at-symbol `@` immediately followed by a non-empty name. Most characters are allowed except whitespace and punctuation used for other parts of block directive syntax unless they are escaped, such as parentheses `()`, curly brackets `{}`, commas `,`, and colons `:`.

```
BlockDirectiveOpening -> @ BlockDirectiveName
BlockDirectiveName -> [^(){}:, \t]
```

## Argument Text

Block directives can have one or more *argument text segments* inside parentheses.

```
ArgumentText -> ( ArgumentTextSegment ArgumentTextRest? )
              | ε
ArgumentTextRest -> \n ArgumentText
ArgumentTextSegment* -> [^)]

* Escaping allowed with a backslash \ character.
```

If you don't need any argument text, you can simply omit the parentheses.

```
@Directive {
    - A
    - B
    - C
}
```

You can parse argument text segments however you like. Swift Markdown also includes a default name-value argument parser that can cover lots of use cases. These are comma-separated pairs of name and value *literals*. For example:

```markdown
@Directive(x: 1, y: "2")
```

When using the name-value argument parser, this results in arguments `x` with value `1` and `y` with value `2`. Names and values are both strings; it's up to you to decide how to convert them into something more specific.

Here is the grammar of name-value argument syntax:

```
Arguments -> Argument ArgumentsRest?
ArgumentsRest -> , Arguments
Argument -> Literal : Literal
Literal -> QuotedLiteral
         | UnquotedLiteral
QuotedLiteral -> " QuotedLiteralContent "
QuotedLiteralContent* -> [^:{}(),"]
UnquotedLiteral* -> [^ \t:{}(),"]

* Escaping allowed with a backslash \ character.
```

> Note: Because of the way Markdown is usually parsed, name-value arguments cannot span multiple lines.

## Content

Wrap content with curly brackets `{}`.

```markdown
@Outer {
  @Inner {
    - A
    - B
    - C
  }
}
```

If a block directive doesn't have any content, you can omit the curly brackets:

```
@TOC

# Title

...
```

## Nesting and Indentation

Since it's very common for block directives to nest, you can indent the lines that make up the name, arguments, and contents any amount.

```markdown
@Outer {
        @Inner {
          - A
            - B
        }
}
```

For the contents, indentation is established by the first non-blank line, assuming that indentation for the rest of a directive's contents. Runs of lines that don't make up the definition of a block directive are handed off to the cmark parser. For `@Inner`'s contents above, the cmark parser will see:

```markdown
- A
  - B
```

Swift Markdown adjusts the source locations reported by cmark after parsing.

## Enabling Block Directive Syntax

Pass the `.parseBlockDirectives` option when parsing a document to enable block directive syntax:

```swift
let document = Document(parsing: source, options: .parseBlockDirectives)
```

## Collecting Diagnostics

When parsing block directive syntax, Swift Markdown supplies an optional diagnostic infrastructure for reporting parsing problems to a user. See ``Diagnostic``, ``DiagnosticEngine``, and ``DiagnosticConsumer``.

Here is a simple case if you just want to collect diagnostics:

```swift
class DiagnosticCollector: DiagnosticConsumer {
    var diagnostics = [Diagnostic]()
    func receive(_ diagnostic: Diagnostic) {
        diagnostics.append(diagnostic)
    }
}

let collector = DiagnosticCollector()
let diagnostics = DiagnosticEngine()
diagnostics.subscribe(collector)

let document = Document(parsing: source,
                        options: .parseBlockDirectives,
                        diagnostics: diagnostics)

for diagnostic in collector.diagnostics {
  print(diagnostic)
}
```

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
