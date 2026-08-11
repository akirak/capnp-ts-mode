;;; capnp-ts-mode.el --- Tree-sitter mode for Cap'n Proto  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Akira Komamura

;; Author: Akira Komamura <akira.komamura@gmail.com>
;; Version: 0.1
;; Keywords: languages, capnproto
;; Package-Requires: ((emacs "29.1"))
;; URL: https://github.com/akirak/capnp-ts-mode

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A major mode for Cap'n Proto schema files, powered by tree-sitter.
;; Install the `capnp' tree-sitter grammar before enabling the mode.

;;; Code:

(require 'treesit)

(defgroup capnp nil
  "Editing Cap'n Proto schema files."
  :group 'languages)

(defcustom capnp-ts-mode-indent-offset 2
  "Number of spaces used for each indentation level."
  :type 'integer
  :safe #'integerp
  :group 'capnp)

(defvar capnp-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "<" table)
    (modify-syntax-entry ?\n ">" table)
    (modify-syntax-entry ?\\ "\\" table)
    (modify-syntax-entry ?' "\"" table)
    table)
  "Syntax table used by `capnp-ts-mode'.")

(defconst capnp-ts-mode--definition-types
  (regexp-opt '("annotation" "const" "enum" "group" "interface"
                "method" "struct" "union"))
  "Regexp matching nodes treated as definitions.")

(defvar capnp-ts-mode--indent-rules
  `((capnp
     ((parent-is "message") column-0 0)
     ((node-is "}") parent-bol 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((parent-is "block_text") no-indent 0)
     ((parent-is "string") no-indent 0)
     ((parent-is "struct") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "enum") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "group") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "union") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "interface") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "method_parameters") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "parameters") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "named_return_types") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "named_return_type") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "generics") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "implicit_generics") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "annotation_targets") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "annotation_array") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "const_list") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "struct_shorthand") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "method") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "field") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "const") parent-bol capnp-ts-mode-indent-offset)
     ((parent-is "annotation") parent-bol capnp-ts-mode-indent-offset)
     (no-node parent-bol 0)))
  "Tree-sitter indentation rules for `capnp-ts-mode'.")

(defvar capnp-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'capnp
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'capnp
   :feature 'definition
   :override t
   '((struct (type_identifier) @font-lock-type-face)
     (interface (type_identifier) @font-lock-type-face)
     (enum (enum_identifier) @font-lock-type-face)
     (group (type_identifier) @font-lock-type-face)
     (annotation
      (annotation_definition_identifier) @font-lock-function-name-face)
     (method (method_identifier) @font-lock-function-name-face)
     (field_identifier) @font-lock-property-name-face
     (param_identifier) @font-lock-variable-name-face
     (return_identifier) @font-lock-variable-name-face)

   :language 'capnp
   :feature 'keyword
   '(["annotation" "const" "enum" "extends" "group" "interface"
      "struct" "union"] @font-lock-keyword-face)

   :language 'capnp
   :feature 'include
   '(["$import" "embed" "import" "using"] @font-lock-preprocessor-face
     (import_path) @font-lock-string-face)

   :language 'capnp
   :feature 'type
   '((primitive_type) @font-lock-builtin-face
     "List" @font-lock-builtin-face
     (type_definition) @font-lock-type-face
     [(extend_type) (generic_identifier)] @font-lock-type-face
     (custom_type (type_identifier) @font-lock-type-face)
     (replace_using (type_identifier) @font-lock-type-face)
     (import_using (type_identifier) @font-lock-type-face)
     (unnamed_return_type (type_identifier) @font-lock-type-face))

   :language 'capnp
   :feature 'constant
   '([(boolean) (void)] @font-lock-constant-face
     [(const_identifier) (local_const) (enum_member)] @font-lock-constant-face
     [(field_version) (unique_id)] @font-lock-constant-face)

   :language 'capnp
   :feature 'number
   '([(number) (float)] @font-lock-number-face)

   :language 'capnp
   :feature 'string
   '([(string) (concatenated_string) (block_text) (namespace)]
     @font-lock-string-face)

   :language 'capnp
   :feature 'property
   '([(property) (attribute) (annotation_identifier)]
     @font-lock-property-use-face)

   :language 'capnp
   :feature 'escape-sequence
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :language 'capnp
   :feature 'operator
   '(["=" "->"] @font-lock-operator-face)

   :language 'capnp
   :feature 'bracket
   '(["(" ")" "[" "]" "{" "}"] @font-lock-bracket-face)

   :language 'capnp
   :feature 'delimiter
   '(["," ";" ":"] @font-lock-delimiter-face)

   :language 'capnp
   :feature 'preprocessor
   '([(top_level_annotation_body) (data_hex)]
     @font-lock-preprocessor-face)

   :language 'capnp
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Tree-sitter font-lock settings for `capnp-ts-mode'.")

(defun capnp-ts-mode--named-child (node type)
  "Return NODE's first named child whose type is TYPE."
  (let ((index 0)
        child)
    (while (and (< index (treesit-node-child-count node t))
                (not (and (setq child (treesit-node-child node index t))
                          (equal (treesit-node-type child) type))))
      (setq index (1+ index)))
    (and child (equal (treesit-node-type child) type) child)))

(defun capnp-ts-mode--defun-name (node)
  "Return the name of definition NODE, or nil for an unnamed union."
  (when-let* ((name-type
               (pcase (treesit-node-type node)
                 ("annotation" "annotation_definition_identifier")
                 ("const" "const_identifier")
                 ("enum" "enum_identifier")
                 ("method" "method_identifier")
                 ((or "group" "interface" "struct" "union")
                  "type_identifier")))
              (name-node (capnp-ts-mode--named-child node name-type)))
    (treesit-node-text name-node t)))

;;;###autoload
(define-derived-mode capnp-ts-mode prog-mode "Cap'n Proto"
  "Major mode for editing Cap'n Proto schemas using tree-sitter."
  :group 'capnp
  :syntax-table capnp-ts-mode--syntax-table

  (unless (treesit-ready-p 'capnp)
    (user-error
     "The Cap'n Proto tree-sitter grammar is unavailable; install the `capnp' grammar first"))

  (setq treesit-primary-parser (treesit-parser-create 'capnp))

  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "#+[ \t]*")

  (setq-local treesit-defun-type-regexp capnp-ts-mode--definition-types)
  (setq-local treesit-defun-name-function #'capnp-ts-mode--defun-name)
  (setq-local treesit-thing-settings
              '((capnp
                 (list "annotation_array" "annotation_targets" "const_list"
                       "generics" "implicit_generics" "method_parameters"
                       "named_return_types" "struct_shorthand")
                 (sentence "statement" "field" "method"))))

  (setq-local treesit-simple-imenu-settings
              `(("Struct" "\\`struct\\'" nil capnp-ts-mode--defun-name)
                ("Interface" "\\`interface\\'" nil capnp-ts-mode--defun-name)
                ("Enum" "\\`enum\\'" nil capnp-ts-mode--defun-name)
                ("Group" "\\`group\\'" nil capnp-ts-mode--defun-name)
                ("Union" "\\`union\\'" nil capnp-ts-mode--defun-name)
                ("Method" "\\`method\\'" nil capnp-ts-mode--defun-name)
                ("Constant" "\\`const\\'" nil capnp-ts-mode--defun-name)
                ("Annotation" "\\`annotation\\'" nil capnp-ts-mode--defun-name)))

  (setq-local indent-tabs-mode nil)
  (setq-local treesit-simple-indent-rules capnp-ts-mode--indent-rules)
  (setq-local electric-indent-chars (append '(?{ ?} ?\( ?\))
                                             electric-indent-chars))

  (setq-local treesit-font-lock-settings capnp-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (keyword include string type)
                (constant number preprocessor property)
                (bracket delimiter error escape-sequence operator)))

  (treesit-major-mode-setup))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.capnp\\'" . capnp-ts-mode))

(provide 'capnp-ts-mode)

;;; capnp-ts-mode.el ends here
