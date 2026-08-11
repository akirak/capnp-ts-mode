;;; capnp-ts-mode-test.el --- Tests for capnp-ts-mode  -*- lexical-binding: t; -*-

(require 'ert)
(require 'imenu)
(require 'treesit)
(require 'capnp-ts-mode)

(defconst capnp-ts-mode-test--schema
  "# Address book.
struct Person {
  name @0 :Text;
  phones @1 :List(Text) = [
    \"home\",
    \"work\",
  ];
}

interface Directory {
  lookup @0 (
    name :Text
  ) -> (
    person :Person
  );
}
")

(defmacro capnp-ts-mode-test--with-buffer (contents &rest body)
  "Create a temporary Cap'n Proto buffer with CONTENTS and run BODY."
  (declare (indent 1) (debug t))
  `(progn
     (unless (treesit-ready-p 'capnp)
       (ert-skip "The capnp tree-sitter grammar is unavailable"))
     (with-temp-buffer
       (insert ,contents)
       (capnp-ts-mode)
       ,@body)))

(defun capnp-ts-mode-test--face-at (text)
  "Return the font-lock face at the first occurrence of TEXT."
  (goto-char (point-min))
  (search-forward text)
  (get-text-property (- (point) (length text)) 'face))

(defun capnp-ts-mode-test--has-face-p (actual expected)
  "Return non-nil when ACTUAL includes face EXPECTED."
  (if (listp actual)
      (memq expected actual)
    (eq actual expected)))

(ert-deftest capnp-ts-mode-test-setup ()
  (capnp-ts-mode-test--with-buffer "struct Empty {}\n"
    (should (eq major-mode 'capnp-ts-mode))
    (should (equal comment-start "# "))
    (should (equal comment-end ""))
    (should (= tab-width 8))
    (should-not indent-tabs-mode)
    (should treesit-primary-parser)))

(ert-deftest capnp-ts-mode-test-font-lock ()
  (capnp-ts-mode-test--with-buffer capnp-ts-mode-test--schema
    (font-lock-ensure)
    (should (capnp-ts-mode-test--has-face-p
             (capnp-ts-mode-test--face-at "Address book")
             'font-lock-comment-face))
    (should (capnp-ts-mode-test--has-face-p
             (capnp-ts-mode-test--face-at "struct")
             'font-lock-keyword-face))
    (should (capnp-ts-mode-test--has-face-p
             (capnp-ts-mode-test--face-at "Person")
             'font-lock-type-face))
    (should (capnp-ts-mode-test--has-face-p
             (capnp-ts-mode-test--face-at "lookup")
             'font-lock-function-name-face))
    (should (capnp-ts-mode-test--has-face-p
             (capnp-ts-mode-test--face-at "Text")
             'font-lock-builtin-face))))

(ert-deftest capnp-ts-mode-test-indentation ()
  (capnp-ts-mode-test--with-buffer
      "struct Person {
name @0 :Text;
phones @1 :List(Text) = [
\"home\",
\"work\",
];
}
"
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string)
                   "struct Person {
  name @0 :Text;
  phones @1 :List(Text) = [
    \"home\",
    \"work\",
  ];
}
"))))

(ert-deftest capnp-ts-mode-test-defun-navigation-and-imenu ()
  (capnp-ts-mode-test--with-buffer capnp-ts-mode-test--schema
    (goto-char (point-max))
    (beginning-of-defun)
    (should (looking-at "interface Directory"))
    (let ((index (imenu--make-index-alist t)))
      (should (assoc "Struct" index))
      (should (assoc "Interface" index))
      (should (assoc "Person" (cdr (assoc "Struct" index))))
      (should (assoc "Directory" (cdr (assoc "Interface" index)))))))

(ert-deftest capnp-ts-mode-test-file-association ()
  (should (eq (assoc-default "example.capnp" auto-mode-alist #'string-match)
              'capnp-ts-mode)))

(provide 'capnp-ts-mode-test)

;;; capnp-ts-mode-test.el ends here
