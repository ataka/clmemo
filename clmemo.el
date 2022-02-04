;;; clmemo.el --- Change Log MEMO
;; -*- Mode: Emacs-Lisp -*-

;; Copyright (c) 2002, 2003, 2004, 2005, 2014, 2016  Masayuki Ataka <masayuki.ataka@gmail.com>

;; Author: Masayuki Ataka <masayuki.ataka@gmail.com>
;; URL: https://github.com/ataka/clmemo
;; Version: 1.0.0
;; Keywords: convenience

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, you can either send email to this
;; program's maintainer or write to: The Free Software Foundation,
;; Inc.; 59 Temple Place, Suite 330; Boston, MA 02111-1307, USA.

;;; Commentary:

;; clmemo provides some commands and minor modes for ChangeLog MEMO.

;; `ChangeLog MEMO' is a kind of concept that writing memo into _ONE_
;; file in ChangeLog format.  You can take a memo about address book,
;; bookmark, diary, idea, memo, news, schedule, time table, todo list,
;; citation from book, one-liner that you wrote but will forget, etc....
;;
;; (1) Why one file?
;;
;; * Easy for you to copy and move file, to edit memo, and to find
;;   something important.
;;
;; * Obvious that text you want is in this file.  In other words, if not
;;   in this file, you didn't take a memo about it.  You will be free
;;   from searching all of the files for what you have taken or might
;;   have not.
;;
;; (2) Why ChangeLog format?
;;
;; * One of well known format.
;;
;; * A plain text file.  Binary is usually difficult to edit and search.
;;   File size gets bigger.  And most of binary file needs special soft.
;;   You should check that your soft is distributed permanently.
;;
;; * Easier to read than HTML and TeX.
;;
;; * Entries are automatically sorted by chronological order.  The
;;   record when you wrote memo is stored.
;;

;; Ref.
;;
;; * ChangeLog
;;
;;  - Change Logs in `GNU Emacs Reference Manual'
;;
;; * ChangeLog MEMO
;;
;;  - http://0xcc.net/unimag/1/ (Japanese)
;;

;; [Acknowledgement]
;;
;; Special thanks to rubikitch for clmemo-yank, clmemo-indent-region,
;; and bug fix of quitting title.  Great thanks goes to Tetsuya Irie,
;; Souhei Kawazu, Shun-ichi Goto, Hideaki Shirai, Keiichi Suzuki, Yuuji
;; Hirose, Katsuwo Mogi, and ELF ML members for all their help.
;;

;; [How to install]
;;
;; The latest clmemo.el is available at:
;;
;;   https://github.com/ataka/clmemo
;;

;; Put this in your .emacs file:
;;
;;   (autoload 'clmemo "clmemo" "ChangeLog memo mode." t)

;; And bind it to your favourite key and set titles of MEMO.
;;
;; Example:
;;
;;   (global-set-key "\C-xM" 'clmemo)
;;   (setq clmemo-title-list
;;        '("Emacs" "Music" ("lotr" . "The Load of the Rings") etc...))
;;

;; Finally, put this at the bottom of your ChangeLog MEMO file.
;;
;;   ^L
;;   Local Variables:
;;   mode: change-log
;;   clmemo-mode: t
;;   End:
;;
;; This code tells Emacs to set major mode change-log and toggle minor
;; mode clmemo-mode ON in your ChangeLog MEMO.  For more information,
;; see section "File Variables" in `GNU Emacs Reference Manual'.
;;
;; `^L' is a page delimiter.  You can insert it by `C-q C-l'.
;;
;; If you are Japanese, it is good idea to specify file coding system
;; like this;
;;
;;   ^L
;;   Local Variables:
;;   mode: change-log
;;   clmemo-mode: t
;;   coding: utf-8
;;   End:
;;

;; [Usage]
;;
;; `M-x clmemo' directly open ChangeLog MEMO file in ChangeLog MEMO
;; mode.  Select your favourite title with completion.  User option
;; `clmemo-title-list' is used for completion.
;;

;; [Related Softwares]
;;
;; * clgrep -- ChangeLog GREP
;;   A grep command specialized for ChangeLog Memo.
;;
;;   - clgrep (Ruby)
;;       http://0xcc.net/unimag/1/
;;   - blgrep (EmacsLisp)
;;       https://github.com/ataka/blgrep
;;
;; * chalow -- CHAnge Log On the Web
;;   A ChangeLog Memo to HTML converter.
;;
;;   - chalow (Perl)
;;       http://chalow.org/


;;; Code:

(require 'add-log)
(eval-and-compile (require 'calendar) (require 'parse-time))
(eval-when-compile (require 'time-date))


;;
;; User Options
;;

(defvar clmemo-file-name "~/clmemo.txt"
  "*ChangeLog MEMO file name.")

(defvar clmemo-time-string-with-weekday nil
  "*If non-nil, append the day of week after date.")

(defvar clmemo-grep-function 'clgrep
  "*Your favourite ChangeLog grep function.")

(defvar clmemo-paragraph-start "[-*] "
  "*Regexp of `paragraph-start' for ChangeLog Memo.")
(defvar clmemo-paragraph-separate "\\(>>\\|<<\\)"
  "*Regexp of `paragraph-paragraph' for ChangeLog Memo.")



;
; title
;
(defvar clmemo-title-list '("idea" "computer")
  "*List of titles.
Set your favourite title of ChangeLog MEMO.
You can set the alias of the title: (alias . title)")

(defvar clmemo-subtitle-char "("
  "*If this char is in the end of title, ask subtitle.")

(defvar clmemo-subtitle-punctuation-char '(" (" . ")")
  "*Car is left string of subtitle punctuation char; Cdr is right.")

(defvar clmemo-title-format-function nil
  "*Function for formatting the title.
The function should take one arg and return the formated string.")

(defvar clmemo-buffer-function-list nil
  "*Function list called after clmemo-new-title.
Function must have one argument BUF.")

(defvar clmemo-new-title-hook nil
  "*Hook run when new title is added.")

;
; tag
;
(defvar clmemo-tag-list '(("url" browse-url-at-point)
			  ("file" find-file-at-point clmemo-read-file-name)
			  ("howm" clmemo-tag-howm-open-file)
			  ("link" clmemo-tag-link-grep clmemo-tag-link-insert)
			  ("rank" clmemo-tag-rank-update clmemo-tag-rank-insert))
  "*List of TAG in ChangeLog MEMO.
You can set functions when insert or jump: (TAG JUMP-FUNCTION INSERT-FUNCTION).")

(defvar clmemo-tag-url "url" "*Tag name for url.")

;
; Quote
;
(defvar clmemo-quote-prefix ">"
  "*Prefix char for quote")

;
; misc
;
(defvar clmemo-schedule-string "[s]"
  "*Header string for schedule.")


;;
;; System Variables and Functions
;;

(defvar clmemo-entry-header-regexp "^\\<.")
(defvar clmemo-item-header-regexp "^\t\\* ")
(defvar clmemo-inline-date "[12][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]")
(defvar clmemo-inline-date-and-num "[12][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]-\\([0-9]+\\)")
(defvar clmemo-inline-date-format "[%s]")
(defvar clmemo-tag-format '("(%s: " . ")"))
(defvar clmemo-winconf nil)

(defvar clmemo-weekdays-regexp
  ;; Variable parse-time-weekdays is defined in parse-time.el
  (regexp-opt (mapcar (lambda (cc) (car cc)) parse-time-weekdays)))

;
; misc functions
;

;; function mapc is a new function from Emacs 21.1.
(defsubst clmemo-mapc (function sequence)
  (if (fboundp 'mapc)
      (mapc function sequence)
    (mapcar function sequence)))


;;
;; font-lock
;;
(defface clmemo-inline-date-face
  '((((class color) (background light))
     (:foreground "slateblue"))
    (((class color) (background dark))
     (:foreground "yellow"))
    (t
     (:bold t)))
  "Face for highlighting date."
  :group 'diary)

(defvar clmemo-inline-date-face 'clmemo-inline-date-face)

(defvar clmemo-font-lock-keywords
  '(;;
    ;; Date lines, with weekday
    ("^\\sw.........[0-9:+ ]*\\((...)\\)?"
     (0 'change-log-date-face)
     ("\\([^<(]+?\\)[ \t]*[(<]\\([A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+\\)[>)]" nil nil
      (1 'change-log-name-face)
      (2 'change-log-email-face)))
    ;;
    ;; Date
    ("\\[[0-9-]+\\]" (0 'clmemo-inline-date-face)))
  "Additional expressions to highlight in ChangeLog Memo mode.")

(setq change-log-font-lock-keywords
      (append clmemo-font-lock-keywords change-log-font-lock-keywords))


;;
;; clmemo
;;

;;;###autoload
(defun clmemo (arg)
  "Open ChangeLog memo file `clmemo-file-name' and ask title.

With prefix argument ARG, just open ChangeLog memo file.
 If already visited the ChangeLog memo file,
 ask title and insert it in the date at point.
With prefix argument more than once, call `clmemo-grep-function'.

See also `add-change-log-entry' and `clmemo-get-title'."
  (interactive "P")
  (cond
   ((equal arg '(64)) (clmemo-grep t))	       ;C-u C-u C-u
   ((equal arg '(16)) (clmemo-grep nil))       ;C-u C-u
   ((equal arg '(4))  (clmemo-one-prefix-arg)) ;C-u
   (t (clmemo-new-title-today))))

(defun clmemo-one-prefix-arg ()
  "Function callend from C-u `clmemo'."
  (let ((file (expand-file-name clmemo-file-name)))
    (if (equal (buffer-file-name) file)
	(clmemo-new-title t)
      (setq clmemo-winconf (current-window-configuration))
      (switch-to-buffer (or (get-file-buffer file)
			    (find-file-noselect file)))
      (clmemo-mode))))

(defun clmemo-new-title-today ()
  "Ask title and insert it.
Function called from `clmemo'."
  (setq clmemo-winconf (current-window-configuration))
  (clmemo-new-title)
  (clmemo-mode))

(defun clmemo-new-title (&optional not-today)
  "Ask title and insert it.
If optional argument NOT-TODAY is non-nil, insert title the date at point."
  (let ((title (clmemo-get-title))
	(buf (current-buffer))
	(add-log-always-start-new-record nil)
	(add-log-time-format (if clmemo-time-string-with-weekday
				 'add-log-iso8601-time-string-with-weekday
			       'add-log-iso8601-time-string)))
    (if not-today
	(progn
	  (forward-line 1)
	  (clmemo-backward-entry)
	  (end-of-line)
	  (insert "\n\n\t* "))
      (add-change-log-entry nil clmemo-file-name t)
      (beginning-of-line)
      (when (looking-at "^\t\\* .+: ")
	(replace-match "\t* "))
      (end-of-line))
    ;; Insert item-heading separator after title.
    (unless (string= "" title)
      (insert title ": "))
    (clmemo-mapc (lambda (func) (funcall func buf)) clmemo-buffer-function-list)
    (run-hooks 'clmemo-new-title-hook)))

(defun clmemo-get-title ()
  "Ask title of ChangeLog MEMO and return it.
Ask the subtitle if `clmemo-subtitle-char' is at the end of title."
  (let ((title (clmemo-completing-read "clmemo title: ")))
    (when (clmemo-subtitle-p title)
      (setq title (clmemo-split-title title))
      (let* ((sub   (clmemo-completing-read (format "subtitle for `%s': " title)))
	     (left  (car clmemo-subtitle-punctuation-char))
	     (right (cdr clmemo-subtitle-punctuation-char)))
	;; Recursive subtitle
	(while (clmemo-subtitle-p sub)
	  (setq title (concat title left (clmemo-split-title sub) right)
		sub (clmemo-completing-read (format "subtitle for `%s': " title))))
	(unless (equal sub "")
	  (setq title (concat title left sub right)))))
    title))

(defun clmemo-completing-read (prompt)
  "Read a string in the minibuffer, with completion using `clmemo-title-list'.
PROMPT is a string to prompt with; normally it ends in a colon and space."
  (let* ((completion-ignore-case t)
	 (alist (mapcar (lambda (x) (if (consp x) x (cons x x)))
			clmemo-title-list))
	 (title (completing-read prompt alist))
	 (subp (clmemo-subtitle-p title)))
    ;; Get title
    (when subp
      (setq title (clmemo-split-title title)))
    (setq title (or (cdr (assoc title alist)) title))
    ;; Format title.
    (when clmemo-title-format-function
      (setq title (funcall clmemo-title-format-function title)))
    ;; Add subtitle suffix if needed.
    (if subp
	(concat title clmemo-subtitle-char)
      title)))

(defun clmemo-subtitle-p (title)
  "Return t if argument TITLE has subtitle suffix.
Subtitle suffix is defined in variable `clmemo-subtitle-char'."
  (and clmemo-subtitle-char
       (not (string= title ""))
       (string= clmemo-subtitle-char (clmemo-split-title title t))))

(defun clmemo-split-title (title &optional tail)
  "Return the substring of TITLE.

A substring is the title which the the length of
`clmemo-split-title' is deleted from tail of the title.
If optional argument TAIL is non-nil, return the deleted one."
  (if tail
      (substring title (- (length clmemo-subtitle-char)))
    (substring title 0 (- (length clmemo-subtitle-char)))))

;
; Buffer Function
;

(defun clmemo-insert-region (buf)
  "Insert the text between region to clmemo if the region is available."
  (when (and (bufferp buf)
	     (with-current-buffer buf (clmemo-region-exists-p)))
    (let ((text (with-current-buffer buf
		  (buffer-substring-no-properties
		   (region-beginning) (region-end))))
	  beg end)
      (save-excursion
	(insert "\n")
	(setq beg (point)
	      end (progn (insert text) (point)))
	(clmemo-indent-region beg end)))))

(defun clmemo-tag-insert-url-from-w3m (buf)
  "Insert w3m's title and url to clmemo if the buffer BUF is under emacs-w3m."
  (when (and (bufferp buf) (featurep 'w3m)
	     (eq 'w3m-mode (with-current-buffer buf
			     (symbol-value 'major-mode))))
    (let (url title exist-p tag (c ?i) blog tmp)
      (with-current-buffer buf
	(setq url (if (boundp 'w3m-current-url) w3m-current-url)
	      title (if (boundp 'w3m-current-title) w3m-current-title)
	      tag (concat (format (car clmemo-tag-format) "url") url ")")))
      (when (and title
		 (string-match "\\(.+\\)[:：][ \t]*" title)
		 (setq blog (match-string 1 title)
		       tmp  (match-string 0 title))
		 (y-or-n-p (format "Split blog title `%s'" blog)))
	(setq title (substring title (length tmp))))
      (save-excursion
	(goto-char (point-min))
	(setq exist-p
	      (when (search-forward tag nil t)
		(clmemo-get-date))))
      (when exist-p
	(setq c (read-char
		 (format "This url is already exists on %s-%s-%s: (G)o  (I)nsert (Q)uit"
			 (nth 5 exist-p) (nth 4 exist-p) (nth 3 exist-p)))))
      (cond
       ((equal c ?i)			;ignore
	;; Insert title
	(when (and title (y-or-n-p (format "Insert `%s' as title? " title)))
	  (insert title))
	(when blog
	  (insert (format "\n\t(blog: %s)\n\t" blog)))
	;; Insert url
	   (save-excursion
	     (when (and url (y-or-n-p "Insert URL? "))
	       (insert "\n\t")
	       (clmemo-tag-insert-url url))))
       ((equal c ?g)			;go to the item which contains url-tag
	(search-forward tag nil t)
	(clmemo-previous-item))
       (t ;quit
	   )
       ))))



;;
;; ChangeLog MEMO Mode
;;
(defvar clmemo-mode nil
  "Toggle clmemo-mode.")
(make-variable-buffer-local 'clmemo-mode)

;; Variable minor-mode-list comes after Emacs-21.4.
(when (boundp 'minor-mode-list)
  (unless (memq 'clmemo-mode minor-mode-list)
    (setq minor-mode-list (cons 'clmemo-mode minor-mode-list)))
)

(unless (assq 'clmemo-mode minor-mode-alist)
  (setq minor-mode-alist
	(cons '(clmemo-mode " MEMO") minor-mode-alist)))

(defvar clmemo-mode-hook nil
  "*Hook run at the end of function `clmemo-mode'.")

(defun clmemo-mode (&optional arg)
  "Minor mode for editing ChangeLog MEMO.
For detail, See function `clmemo'.

\\{clmemo-mode-map}
"
  (interactive "P")
  (if (< (prefix-numeric-value arg) 0)
      (setq clmemo-mode nil)
    (setq clmemo-mode t)
    (unless (local-variable-p 'paragraph-start)
      (make-local-variable 'paragraph-start))
    (setq paragraph-start (concat clmemo-paragraph-start "\\|" paragraph-start))
    (unless (local-variable-p 'paragraph-separate)
      (make-local-variable 'paragraph-separate))
    (setq paragraph-separate (concat clmemo-paragraph-separate "\\|" paragraph-separate))
    (run-hooks 'clmemo-mode-hook)))

(defvar clmemo-mode-map nil)
(if clmemo-mode-map
    nil
  (let ((map (make-keymap)))
    ;; Movement & mark
    (define-key map "\C-c\C-n" 'clmemo-next-item)
    (define-key map "\C-c\C-p" 'clmemo-previous-item)
    (define-key map "\C-c\C-f" 'clmemo-forward-entry)
    (define-key map "\C-c\C-b" 'clmemo-backward-entry)
    (define-key map "\C-c}" 'clmemo-previous-month)
    (define-key map "\C-c{" 'clmemo-next-month)
    (define-key map "\C-c\C-h" 'clmemo-mark-month)
    (substitute-key-definition 'forward-page 'clmemo-previous-year map global-map)
    (substitute-key-definition 'backward-page 'clmemo-next-year map global-map)
    (substitute-key-definition 'mark-page 'clmemo-mark-year map global-map)
    ;; yank & indent
    (define-key map "\C-c\C-w" 'clmemo-kill-ring-save)
    (define-key map "\C-c\C-y" 'clmemo-yank)
    (define-key map "\C-c\C-i" 'clmemo-indent-region)
    (define-key map "\C-c>" 'clmemo-quote-region)
    ;; Date
    (define-key map "\C-c\C-d" 'clmemo-inline-date-insert)
    (define-key map "\C-i" 'clmemo-next-inline-date)
    (define-key map [(shift tab)] 'clmemo-previous-inline-date)
    (define-key map [backtab] 'clmemo-previous-inline-date)
    ;; Tag
    (define-key map "\C-c(" 'clmemo-tag-insert-quick)
    (define-key map "\C-c\C-t" 'clmemo-forward-tag)
    (define-key map "\C-c;" 'clmemo-forward-tag)
    (define-key map "\C-c:" 'clmemo-backward-tag)
    ;; List
    (define-key map "\C-c)l"  'clmemo-list-link)
    (define-key map "\C-c)r"  'clmemo-list-rank)
    (define-key map "\C-c)Rd"  'clmemo-list-rank-date)
    (define-key map "\C-c)Rn"  'clmemo-list-rank-num)
    ;; Schedule
    (define-key map "\C-c\C-c" 'clmemo-schedule)
    ;; Exit
    (define-key map "\C-c\C-q" 'clmemo-exit)
    (define-key map "\C-c\C-m" 'clmemo-jump)
    (setq clmemo-mode-map map)))

(unless (assq 'clmemo-mode minor-mode-map-alist)
  (setq minor-mode-map-alist
	(cons (cons 'clmemo-mode clmemo-mode-map) minor-mode-map-alist)))

(defun clmemo-next-item (&optional arg)
  "Move to the next item.
With argument, repeats or can move backward if negative."
  (interactive "p")
  (re-search-forward clmemo-item-header-regexp nil t arg)
  (beginning-of-line)
  (skip-chars-forward "\t"))

(defun clmemo-previous-item (&optional arg)
  "Move to the previous item.
With argument, repeats or can move forward if negative."
  (interactive "p")
  (re-search-backward clmemo-item-header-regexp nil t arg)
  (skip-chars-forward "\t"))

(defun clmemo-forward-entry (&optional arg)
  "Move forward to the ARG'th entry."
  (interactive "p")
  (if (and arg (< arg 0))
      (clmemo-backward-entry (- arg))
    (beginning-of-line)
    (forward-char 1)
    (re-search-forward clmemo-entry-header-regexp nil t arg)
    (beginning-of-line)))

(defun clmemo-backward-entry (&optional arg)
  "Move backward to the ARG'th entry."
  (interactive "p")
  (if (and arg (< arg 1))
      (clmemo-forward-entry (- arg))
    (beginning-of-line)
    (backward-char 1)
    (re-search-backward clmemo-entry-header-regexp nil t arg)
    (beginning-of-line)))

;
; kill-ring Save & Yank
;
(defun clmemo-kill-ring-save (beg end)
  "Same as `kill-ring-save' but remove TAB at the beginning of line."
  (interactive "r")
  (let ((buf (current-buffer)))
    (with-temp-buffer
      (insert-buffer-substring buf beg end)
      (goto-char (point-min))
      (while (re-search-forward "^\t" nil t)
        (replace-match ""))
      (kill-ring-save (point-min) (point-max)))))

(defun clmemo-yank (&optional arg)
  "Yank and indent with one TAB.

Not support `yank-pop'.
Use function `clmemo-indent-region' after `yank' and `yank-pop'."
  (interactive "P*")
  (when (looking-back "^\t[ \t]*" nil)
    (replace-match ""))
  (let ((beg (point))
        (end (progn (yank) (point))))
    (clmemo-indent-region beg end)))

(defun clmemo-indent-region (beg end)
  "Indent region by one TAB."
  (interactive "r*")
  (save-excursion
    (goto-char end)
    (beginning-of-line)
    (while (>= (point) beg)
      (insert "\t")
      (forward-line -1))))

;
; Quote
;
(defun clmemo-quote-region (beg end &optional qstr)
  "Add quote string before every line in the region.
You can customize the quote string by the variable `clmemo-quote-prefix'.

If called with prefix arg, ask quote string."
  (interactive "r*\nP")
  (setq qstr (if qstr
		 (read-string (format "Quote string (%s): " clmemo-quote-prefix)
			      nil nil clmemo-quote-prefix)
	       clmemo-quote-prefix))
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (while (re-search-forward "^\t" nil t)
	(replace-match (concat "\t" qstr " "))))))

(defun clmemo-region-exists-p ()
  "Return t if mark is active."
  (cond
   ((boundp 'mark-active) mark-active)		  ;For Emacs
   ((fboundp 'region-exists-p) (region-exists-p)) ;For XEmacs
   (t (error "No function for checking region"))))

;
; Schedule
;

(defun clmemo-schedule ()
  "Insert schedule flags and puts date string.
See variable `clmemo-schedule-string' for header flag string."
  (interactive)
  (end-of-line)
  (clmemo-previous-item)
  (forward-char 2)
  (insert clmemo-schedule-string)
  (search-forward ": "))

;
; Exit
;

(defun clmemo-exit ()
  "Turn back where enter the ChangeLog memo."
  (interactive)
  (basic-save-buffer)
  (set-window-configuration clmemo-winconf))

(defun clmemo-jump ()
  "Jump command for clmemo.
Change behaviour depending on the text at point."
  (interactive)
  (cond ((clmemo-inline-date-p) (clmemo-goto-date))
	((clmemo-tag-p) (clmemo-tag-func))
	((thing-at-point 'url) (browse-url-at-point))
	(t nil)))

(defun clmemo-tag-func ()
  "Function called at tag.
Change behaviour depending on the tag at point."
  (skip-chars-backward "^(")
  (when (looking-at "\\([^:]+\\): ")
    (let* ((tag (match-string 1))
	   (cc (assoc tag clmemo-tag-list)))
      (search-forward ": " nil t)
      (when cc
	(funcall (nth 1 cc))))))


;;
;; Date
;;
(defun clmemo-get-week (&optional time)
  "Return the abbreviated name of the day of week."
  (unless time
    (setq time (current-time)))
  (substring (current-time-string time) 0 3))

(defun clmemo-get-date (&optional today)
  "Return the list of (0 0 0 DAY MONTH YEAR DOW) of the entry at point.
If optional argument TODAY is non-nil, return the list of today."
  (let (year month day dow)
    (if today
	(let ((time (decode-time)))
	  (setq dow (nth 6 time)
		year (nth 5 time)
		month (nth 4 time)
		day (nth 3 time)))
      (save-excursion
	(forward-line 1)
	(clmemo-backward-entry)
	(let ((end (save-excursion (end-of-line) (point))))
	  (and (re-search-forward "^[0-9]+" end t)
	       (setq year (string-to-number (match-string 0))))
	  (skip-chars-forward "-" end)
	  (and (re-search-forward "[0-9]+" end t)
	       (setq month (string-to-number (match-string 0))))
	  (skip-chars-forward "-" end)
	  (and (re-search-forward "[0-9]+" end t)
	       (setq day (string-to-number (match-string 0)))))
	;; function calendar-day-of-week is defined in calendar.
	(setq dow (calendar-day-of-week `(,month ,day ,year)))))
    (list 0 0 0 day month year dow)))

(defun clmemo-forward-year (&optional arg)
  "Move forward year.
With argument, repeats or can move backward if negative."
  (interactive "p")
  (unless arg (setq arg 1))
  (if (< arg 0)
      (clmemo-backward-year (- arg))
    (when (called-interactively-p 'interactive) (push-mark))
    (let ((year (nth 5 (clmemo-get-date)))
	  (pos (point)))
      (setq year (+ year arg))
      (goto-char (point-min))
      (if (re-search-forward (format "^%d-" year) nil t)
	  (beginning-of-line)
	(goto-char pos)
	(when (called-interactively-p 'interactive) (pop-mark))))))

(defun clmemo-backward-year (&optional arg)
  "Move backward year.
With argument, repeats or can move forward if negative."
  (interactive "p")
  (unless arg (setq arg 1))
  (if (< arg 1)
      (clmemo-forward-year (- arg))
    (when (called-interactively-p 'interactive) (push-mark))
    (let ((year (nth 5 (clmemo-get-date))))
      (setq year (- year arg))
      (if (re-search-forward (format "^%d-" year) nil t)
	  (beginning-of-line)
	(when (called-interactively-p 'interactive) (pop-mark))))))

(defun clmemo-next-year (&optional arg)
  "Move to the date after ARG's year.
With argument, repeats or can move backward if negative."
  (interactive "p")
  (unless arg (setq arg 1))
  (if (< arg 0)
      (clmemo-backward-year (- arg))
    (when (called-interactively-p 'interactive) (push-mark))
    (let ((date (clmemo-get-date))
	  (pos (point))
	  year month day regexp)
      (setq year (+ arg (nth 5 date))
	    month (nth 4 date)
	    day (nth 3 date))
      (if (= arg 0)
	  (setq regexp (format "^%d-" year))
	(setq regexp (format "^%d-%02d-%02d" year month day)))
      (goto-char (point-min))
      (if (re-search-forward regexp nil t)
	  (beginning-of-line)
	(goto-char pos)
	(when (called-interactively-p 'interactive) (pop-mark))))))

(defun clmemo-previous-year (&optional arg)
  "Move to the date before ARG's year.
With argument, repeats or can move forward if negative."
  (interactive "p")
  (unless arg (setq arg 1))
  (if (< arg 1)
      (clmemo-forward-year (- arg))
    (when (called-interactively-p 'interactive) (push-mark))
    (let ((date (clmemo-get-date))
	  year month day)
      (setq year (- (nth 5 date) arg)
	    month (nth 4 date)
	    day (nth 3 date))
      (if (re-search-forward (format "^%d-%02d-%02d" year month day) nil t)
	  (beginning-of-line)
	(when (called-interactively-p 'interactive) (pop-mark))))))

(defun clmemo-forward-month (&optional arg)
  "Move forward month.
With argument, repeats or can move backward if negative."
  (interactive "p")
  (unless arg (setq arg 1))
  (if (< arg 0)
      (clmemo-backward-month (- arg))
    (when (called-interactively-p 'interactive) (push-mark))
    (let ((time (clmemo-get-date))
	  (pos (point))
	  year month)
      (setq year (nth 5 time)
	    month (nth 4 time))
      (setq month (+ month arg))
      (when (> month 12)
	(setq year (+ year (/ month 12))
	      month (% month 12)))
      (goto-char (point-min))
      (if (re-search-forward (format "^%d-%02d-" year month) nil t)
	  (beginning-of-line)
	(goto-char pos)
	(when (called-interactively-p 'interactive) (pop-mark))))))

(defun clmemo-backward-month (&optional arg)
  "Move backward month.
With argument, repeats or can move forward if negative."
  (interactive "p")
  (unless arg (setq arg 1))
  (if (< arg 1)
      (clmemo-forward-month (- arg))
    (when (called-interactively-p 'interactive) (push-mark))
    (let ((time (clmemo-get-date))
	  year month)
      (setq year (nth 5 time)
	    month (nth 4 time))
      (if (> month arg)
	  (setq month (- month arg))
	(setq arg (- arg month))
	(setq year (- year (1+ (/ arg 12)))
	      month (- 12 (% arg 12))))
      (if (re-search-forward (format "^%d-%02d-" year month) nil t)
	  (beginning-of-line)
	(when (called-interactively-p 'interactive) (pop-mark))))))

(defun clmemo-next-month (&optional arg)
  "Move to the date after ARG's month.
With argument, repeats or can move backward if negative."
  (interactive "p")
  (unless arg (setq arg 1))
  (if (< arg 0)
      (clmemo-backward-month (- arg))
    (when (called-interactively-p 'interactive) (push-mark))
    (let ((date (clmemo-get-date))
	  (pos (point))
	  year month day regexp)
      (setq year (nth 5 date)
	    month (nth 4 date)
	    day (nth 3 date))
      (setq month (+ month arg))
      (when (> month 12)
	(setq year (+ year (/ month 12))
	      month (% month 12)))
      (if (= arg 0)
	  (setq regexp (format "^%d-%02d-" year month))
	(setq regexp (format "^%d-%02d-%02d" year month day)))
      (goto-char (point-min))
      (if (re-search-forward regexp nil t)
	  (beginning-of-line)
	(goto-char pos)
	(when (called-interactively-p 'interactive) (pop-mark))))))

(defun clmemo-previous-month (&optional arg)
  "Move to the date before ARG's month.
With argument, repeats or can move forward if negative."
  (interactive "p")
  (unless arg (setq arg 1))
  (if (< arg 1)
      (clmemo-forward-month (- arg))
    (when (called-interactively-p 'interactive) (push-mark))
    (let ((date (clmemo-get-date))
	  year month day)
      (setq year (nth 5 date)
	    month (nth 4 date)
	    day (nth 3 date))
      (if (> month arg)
	  (setq month (- month arg))
	(setq arg (- arg month))
	(setq year (- year (1+ (/ arg 12)))
	      month (- 12 (% arg 12))))
      (if (re-search-forward (format "^%d-%02d-%02d" year month day) nil t)
	  (beginning-of-line)
	(when (called-interactively-p 'interactive) (pop-mark))))))

(defun clmemo-mark-year (&optional arg)
  "Put point at end of this year, mark at beginning.
With argument ARG, puts mark at end of a following year, so that
the number of years marked equals ARG."
  (interactive "p")
  (or arg (setq arg 1))
  (clmemo-forward-year 0)
  (push-mark)
  (clmemo-backward-year arg)
  (exchange-point-and-mark))

(defun clmemo-mark-month (&optional arg)
  "Put point at end of this month, mark at beginning.
With argument ARG, puts mark at end of a following month, so that
the number of months marked equals ARG."
  (interactive "p")
  (or arg (setq arg 1))
  (clmemo-forward-month 0)
  (push-mark)
  (clmemo-backward-month arg)
  (exchange-point-and-mark))


;;
;; Inline Date
;;
;; Function define-minor-mode comes after Emacs 21.
;; Reported by TSURUDA Naoki [2002-12-21].
(defvar clmemo-inline-date-mode nil
  "Non-nil if Clmemo-Inline-Date mode is enabled.
Use the command `clmemo-inline-date-mode' to change this variable.")
(make-variable-buffer-local 'clmemo-inline-date-mode)

;; Variable minor-mode-list comes after Emacs-21.
(when (boundp 'minor-mode-list)
  (unless (memq 'clmemo-inline-date-mode minor-mode-list)
    (setq minor-mode-list (cons 'clmemo-inline-date-mode minor-mode-list)))
)

(unless (assq 'clmemo-inline-date-mode minor-mode-alist)
  (setq minor-mode-alist (cons '(clmemo-inline-date-mode " Date") minor-mode-alist)))


(defvar clmemo-inline-date-mode-hook nil
  "*Hook run at the end of function `clmemo-inline-date-mode'.")

(defvar clmemo-inline-date-pos nil)


(defun clmemo-inline-date-insert (&optional arg)
  (interactive "P")
  (if (or (looking-back (concat "\\(" clmemo-weekdays-regexp "\\)[ \t]*") nil)
	      (looking-back "[0-9]+[ \t]*" nil))
      (clmemo-inline-date-convert arg)
    (clmemo-inline-date-mode arg)))

(defun clmemo-inline-date-mode (&optional arg)
  "Minor mode for looking for the date to insert.

\\{clmemo-inline-date-mode-map}"
  (interactive (list (or current-prefix-arg 'toggle)))
  (setq clmemo-inline-date-mode
	(cond ((eq arg (quote toggle)) (not clmemo-inline-date-mode))
	      (arg (> (prefix-numeric-value arg) 0))
	      (t (if (null clmemo-inline-date-mode)
		     t
		   (message "Toggling %s off; better pass an explicit argument."
			    (quote clmemo-inline-date-mode)) nil))))
  (when (and clmemo-inline-date-mode buffer-read-only)
    (setq clmemo-inline-date-mode nil)
    (error "Buffer is read-only: %S" (current-buffer)))
  (if clmemo-inline-date-mode
      (setq buffer-read-only t
	    clmemo-inline-date-pos (cons (point) (current-window-configuration)))
    (setq buffer-read-only nil
	  clmemo-inline-date-pos nil))
  (run-hooks 'clmemo-inline-date-mode-hook)
  (force-mode-line-update)
  clmemo-inline-date-mode)

;
; keymap
;
(defvar clmemo-inline-date-mode-map nil)
(if clmemo-inline-date-mode-map
    nil
  (let ((map (make-keymap)))
    (suppress-keymap map)
    ;; Date
    (define-key map "q"  'clmemo-inline-date-quit)
    (define-key map "\C-m" 'clmemo-inline-date-insert-today)
    ;; Move
    (define-key map "n"  'clmemo-next-item)
    (define-key map "p"  'clmemo-previous-item)
    (define-key map "f"  'clmemo-forward-entry)
    (define-key map "b"  'clmemo-backward-entry)
    (define-key map "}"  'clmemo-backward-month)
    (define-key map "{"  'clmemo-forward-month)
    (define-key map "]"  'clmemo-backward-year)
    (define-key map "["  'clmemo-forward-year)
    (define-key map "s"  'isearch-forward)
    (define-key map "r"  'isearch-backward)
    (define-key map " "  'scroll-up)
    (define-key map [backspace] 'scroll-down)
    (setq clmemo-inline-date-mode-map map)))

(unless (assq 'clmemo-inline-date-mode minor-mode-map-alist)
  (setq minor-mode-map-alist
	(cons (cons 'clmemo-inline-date-mode clmemo-inline-date-mode-map)
	      minor-mode-map-alist)))


(defun clmemo-inline-date-insert-today (&optional arg)
  "Insert the date where point is."
  (interactive "P")
  ;; Get error when called from not clmemo-inline-date-mode.
  (unless clmemo-inline-date-mode
    (error "Call this function from function clmemo-insert-date"))
  (end-of-line)
  (unless (eobp) (forward-line 1))
  (let ((num 0)
	(pos (point)))
    ;; Get item number if ARG is t.
    (when arg
      (save-excursion
	(clmemo-forward-entry)
	(while (< pos (point))
	  (setq num (1+ num))
	  (clmemo-previous-item))))
    ;; Get date and insert it.
    (clmemo-backward-entry)
    (if (looking-at clmemo-inline-date)
	(progn (clmemo-inline-date-quit)
	       (setq buffer-undo-list (cons (point) buffer-undo-list))
	       (insert (format clmemo-inline-date-format
			       (if arg
				   (concat (match-string 0) "-" (number-to-string num))
				 (match-string 0)))))
      (clmemo-inline-date-quit)
      (error "Can't search ChangeLog title"))))

(defun clmemo-inline-date-quit ()
  "Quit clmemo-inline-date-mode."
  (interactive)
  (let ((pos clmemo-inline-date-pos))
    (when (eq major-mode 'clgrep-mode)
      (clmemo-inline-date-mode -1)
      (set-window-configuration (cdr pos)))
    (goto-char (car pos))
    (clmemo-inline-date-mode -1)))

(defun clmemo-inline-date-p ()
  "Return t if point is in the inline date."
  (save-excursion
    (skip-chars-backward "-0-9")
    (skip-chars-forward "[")
    (and (not (looking-at clmemo-entry-header-regexp))
	 (equal (char-before) ?\[)
	 (looking-at clmemo-inline-date))))

(defun clmemo-goto-date (&optional date num)
  "Move point where the date at point."
  (interactive nil)
  (let ((pos (point)))
    ;; Get inline date
    (unless (or date (clmemo-inline-date-p)) (error "No date here"))
    (skip-chars-backward "-0-9")
    (unless date
      (setq date (progn (looking-at clmemo-inline-date)
			(match-string 0))))
    (unless num
      (setq num  (progn (looking-at clmemo-inline-date-and-num)
		      (match-string 1))))
    ;; Goto the date
    (push-mark)
    (goto-char (point-min))
    (if (re-search-forward (concat "^" date) nil t)
	(beginning-of-line)
      (goto-char pos)
      (error "No date: %s" date)))
  (when num
    (setq num (string-to-number num))
    (clmemo-forward-entry)
    (while (> num 0)
      (clmemo-previous-item)
      (unless (looking-at "\\* p:")	;skip private item.
	(setq num (1- num)))))
  (recenter 0))

(defun clmemo-next-inline-date (&optional arg)
  "Search forward ARG'th date from point."
  (interactive "p")
  (let* ((fmt (regexp-quote clmemo-inline-date-format))
	 (regexp (format (concat fmt "\\|" fmt)
			 clmemo-inline-date
			 clmemo-inline-date-and-num)))
    (when (re-search-forward regexp nil t arg)
      (if (< arg 0)
	  (skip-chars-forward "^0-9")
	(skip-chars-backward "^0-9")
	(skip-chars-backward "-0-9")))))

(defun clmemo-previous-inline-date (&optional arg)
  "Search backward ARG'th date from point."
  (interactive "p")
  (clmemo-next-inline-date (- arg)))

;
; inline date converter
;
(defun clmemo-time-to-inline-date (time)
  (format clmemo-inline-date-format
	  (format-time-string "%Y-%m-%d" time)))

(defun clmemo-inline-date-convert (&optional today)
  "Convert number, keywords, etc... to inline date.
If optional argument TODAY is non-nil, change the origin of date today."
  (interactive "P")
  (let ((pos (point))
	(time (clmemo-get-date today))
	idate day month year dow week)
    (setq day (nth 3 time)
	  month (nth 4 time)
	  year (nth 5 time)
	  dow (nth 6 time))
    (skip-syntax-backward "-")
    (when (re-search-backward clmemo-weekdays-regexp (max (point-min) (- (point) 3)) t)
      (setq week (cdr (assoc (match-string 0) parse-time-weekdays))))
    (skip-chars-backward "-+0-9")
    (cond
     ;; ([+-][0-9])?(mon|tue|wed|thu|fri|sat|sun)
     ((numberp week)
      (setq day (- week dow))
      (when (looking-at (concat "\\([-+][0-9]+\\)\\(" clmemo-weekdays-regexp "\\)"))
	(setq day (+ day (* 7 (string-to-number (match-string 1))))))
      (setq idate (clmemo-time-to-inline-date
		   (time-add (apply 'encode-time time) (days-to-time day)))))
     ;; ++++2, ----2 [+year]
     ((looking-at "[-+][-+][-+]\\([-+][0-9]+\\)")
      (setq year (+ year (string-to-number (match-string 1)))))
     ;; +++2, ---2 [+month]
     ((looking-at "[-+][-+]\\([-+][0-9]+\\)")
      (setq month (+ month (string-to-number (match-string 1)))))
     ;; ++2, --2 [+week]
     ((looking-at "[-+]\\([-+][0-9]+\\)")
      (setq day (* 7 (string-to-number (match-string 1))))
      (setq idate (clmemo-time-to-inline-date
		   (time-add (apply 'encode-time time) (days-to-time day)))))
     ;; +12, -12 [+day]
     ((looking-at "[-+][0-9]+")
      (setq day (string-to-number (match-string 0)))
      (setq idate (clmemo-time-to-inline-date
		   (time-add (apply 'encode-time time) (days-to-time day)))))
     ;; 2002-12-12, 88-12-12
     ((looking-at "\\([0-9]+\\)-\\([01]?[0-9]\\)-\\([0-3]?[0-9]\\)")
      (setq year (string-to-number (match-string 1))
	    month (string-to-number (match-string 2))
	    day (string-to-number (match-string 3)))
      (if (> year 100)
	  (setq idate (format clmemo-inline-date-format
			      (format "%04d-%02d-%02d" year month day)))
	;; System recognize 1970~2037
	(if (< 50 year)
	    (setq year (+ 1900 year))
	  (setq year (+ 2000 year)))))
     ;; 12-12
     ((looking-at "\\([01]?[0-9]\\)-\\([0-3]?[0-9]\\)")
      (setq month (string-to-number (match-string 1))
	    day (string-to-number (match-string 2))))
     ;; 12
     ((looking-at "[0-3]?[0-9]")
      (setq day (string-to-number (match-string 0))))
     ;; No match
     (t (goto-char pos) (error "No inline-date convert string")))
    (unless idate
      (setq idate (clmemo-time-to-inline-date
		   (encode-time 0 0 0 day month year))))
    (replace-match "")
    (insert idate)))

;
; Inline date reminder
;
(defun clmemo-reminder ()
  "Inline date reminder.
Reminder looks for `[YYYY-MM-DD]?'

`?' should be one of them:
 @	memo
 +	todo
 !	deadline
 @	schedule
 ~	reserve
"
  (interactive)
  (let ((idate-regexp (concat (format (regexp-quote clmemo-inline-date-format)
				      clmemo-inline-date)
			      "[-+@!~]"))
	date title line pos
	(alist (list (cons (format-time-string "%Y-%m-%d")
			   (format-time-string "[%Y-%m-%d] Today")))))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward idate-regexp nil t)
	(setq date (match-string 1)
	      pos (progn (beginning-of-line) (skip-chars-forward " \t-") (point))
	      line (buffer-substring-no-properties pos
		    (progn (end-of-line)
			   (skip-chars-backward " \t")
			   (point))))
	(save-excursion
	  (clmemo-previous-item 1)
	  (if (<= pos (point))
	      (setq title "")
	    (setq title (buffer-substring-no-properties
			 (progn (backward-char 1) (point))
			 (progn (end-of-line)
				(skip-chars-backward " \t")
				(point))))))
	(setq alist (cons (cons date (concat line title)) alist)))
      (setq alist (sort alist (lambda (c1 c2) (string< (car c2) (car c1))))))
    (pop-to-buffer "*clmemo-reminder*")
    (delete-region (point-min) (point-max))
    (insert "  ==Inline-Date Reminder==\n\n")
    (insert (mapconcat (lambda (cc) (cdr cc)) alist "\n"))
    (goto-char (point-min))
    (search-forward (format-time-string (format-time-string "[%Y-%m-%d] Today")))
    (beginning-of-line)))


;;
;; Tag
;;
(defun clmemo-tag-p ()
  "Return t if point is in the tag."
  (let ((lim (save-excursion (beginning-of-line) (point))))
    (unless (eobp)
      (save-excursion
	(forward-char 1)
	(skip-chars-backward "^(" lim)
	(and (equal (char-before) ?\()
	     (looking-at ".+: .+)"))))))

(defun clmemo-tag-insert-quick (tag)
  "Insert tag quickly.
See also function `clmemo-tag-completing-read'."
  (interactive (list (clmemo-tag-completing-read t)))
  (clmemo-tag-insert tag))

(defun clmemo-tag-insert (tag)
  "Insert tag.
See also function `clmemo-tag-completing-read'."
  (interactive (list (clmemo-tag-completing-read)))
  (let ((cc (assoc tag clmemo-tag-list))
	(fmt-left (car clmemo-tag-format))
	(fmt-right (cdr clmemo-tag-format)))
    (if (> (length cc) 2)
	(setq cc (cons (car cc) (nth 2 cc)))
      (setq cc nil))
    (insert (format fmt-left tag))
    (save-excursion
      (insert fmt-right))
    (if cc
	(funcall (cdr cc)))))

(defun clmemo-tag-completing-read (&optional quick)
  "Return tag name.
The variable `clmemo-tag-list' is used for completion of tag name.

If optional argument QUICK is non-nil, clmemo-tag-completing-read
choose the tag name by the initial letter of tag name.  When
initial letters are overlapped, the first tag name in the
`clmemo-tag-list' will be chosen."
  (let (tag
	(tag-list (mapcar (lambda (elt) (if (listp elt) elt (list elt))) clmemo-tag-list)))
    (save-window-excursion
      (while (not tag)
	(if quick
	    (let ((char (char-to-string (read-char "tag: "))))
	      (cond
	       ((equal char " ") (setq quick nil))
	       ((equal char "\t") (clmemo-tag-show))
	       (t (setq tag (all-completions char tag-list)))))
	  (setq tag (completing-read "tag: " tag-list)))))
    (if (listp tag)
	(car tag)
      tag)))

(defun clmemo-tag-show ()
  "Show the tag name for completion."
  (let ((buf (get-buffer-create " *clmemo-tag*")))
    (switch-to-buffer-other-window buf t)
    (erase-buffer)
    (goto-char (point-min))
    (insert "==* clkwd tag *==\n\n")
    (let (init-letter l)
      (insert (mapconcat (lambda (tag)
			   (unless (stringp tag)
			     (setq tag (car tag)))
			   (setq l (substring tag 0 1))
			   (unless (member l init-letter)
			     (setq init-letter (cons l init-letter))
			     (format "  %s ... %s\n" l tag)))
			 clmemo-tag-list "")))
    (insert "\nC-g for quit.\n")))


(defun clmemo-next-tag (tag &optional arg)
  "Move next tag TAG.
With argument, repeats or can move backward if negative."
  (interactive (list (clmemo-tag-completing-read)
		     (prefix-numeric-value current-prefix-arg)))
  (if (and arg (< arg 0))
      (clmemo-previous-tag (- arg))
    (and (re-search-forward (format "(%s: " tag)  nil t arg)
	 (clmemo-beginning-of-tag-string))))

(defun clmemo-previous-tag (tag &optional arg)
  "Move previous tag TAG.
With argument, repeats or can move forward if negative."
  (interactive (list (clmemo-tag-completing-read)
		     (prefix-numeric-value current-prefix-arg)))
  (if (and arg (< arg 1))
      (clmemo-next-tag (- arg))
    (beginning-of-line)
    (and (re-search-backward (format "(%s: " tag) nil t arg)
	 (clmemo-beginning-of-tag-string))))

(defun clmemo-forward-tag (&optional arg)
  "Move forward to the ARG'th tag.
With argument, repeats or can move backward if negative."
  (interactive "p")
  (if (and arg (< arg 0))
      (clmemo-backward-tag (- arg))
    (and (re-search-forward "^\t(.+: " nil t arg)
	 (clmemo-beginning-of-tag-string))))

(defun clmemo-backward-tag (&optional arg)
  "Move backward to the ARG'th tag.
With argument, repeats or can move forward if negative."
  (interactive "p")
  (if (and arg (< arg 0))
      (clmemo-forward-tag (- arg))
    (beginning-of-line)
    (and (re-search-backward "^\t(.+: " nil t arg)
	 (clmemo-beginning-of-tag-string))))

(defun clmemo-beginning-of-tag-string ()
  "Move point to the beginning of tag, skipping inline date."
  (beginning-of-line)
  (when (re-search-forward "^\t([^:]+:" nil t)
    (skip-chars-forward " ")
    (when (clmemo-inline-date-p)
      (skip-chars-forward "^\]")
      (forward-char 1)
      (skip-chars-forward " "))))
;
; url
;
(defun clmemo-tag-insert-url (url)
  "Insert url URL as tag."
  (clmemo-tag-insert "url")
  (insert url)
  (end-of-line))

(defun clmemo-next-tag-url (&optional arg)
  (interactive "p")
  (clmemo-next-tag clmemo-tag-url arg))

(defun clmemo-previous-tag-url (&optional arg)
  (interactive "p")
  (clmemo-previous-tag clmemo-tag-url arg))

;
; File
;
(defun clmemo-read-file-name ()
  "Read file name."
  (insert (read-file-name "File: ")))

;
; howm
;
(defvar quasi-howm-dir "~/howm/"
  "*Quasi-howm directory")

(defvar quasi-howm-file-name-format "%Y-%m/%Y%m%d-%H%M%S"
  "*Your howm's file name format
See `format-time-string' for the description of constructs.")

(defun quasi-howm ()
  (interactive)
  (let ((file (format "%s%s.howm" quasi-howm-dir
		      (format-time-string quasi-howm-file-name-format))))
    (unless (file-exists-p (file-name-directory file))
      (make-directory (file-name-directory file) t))
    (when (equal (buffer-file-name) (expand-file-name clmemo-file-name))
      (unless (save-excursion (backward-char 1) (looking-at "^\t"))
	(or (looking-at "^") (insert "\n"))
	(insert "\t"))
      (insert (format "(howm: %s)" (file-name-nondirectory file))))
    (find-file file))
  (insert "= ")
  (save-excursion
    (insert "\n" (format-time-string "[%Y-%m-%d %H:%M]\n"))))

(defun clmemo-tag-howm-open-file ()
  (interactive)
  (let ((file (buffer-substring-no-properties
	       (progn (beginning-of-line) (search-forward "(howm: "))
	       (1- (search-forward ")")))))
    (setq file (concat
		(substring file 0 4) "-"
		(substring file 4 6) "/"
		file))
    (find-file (concat quasi-howm-dir file))))

;
; link
;
(defun clmemo-tag-link-grep ()
  (interactive)
  (let (query beg end)
    (setq beg (progn (beginning-of-line) (skip-chars-forward " \t") (point))
	  end (search-forward ")" nil t)
	  query (regexp-quote (buffer-substring-no-properties beg end)))
    (if (fboundp 'clgrep-item)
	(funcall #'clgrep-item query)
      (occur query))))

(defun clmemo-tag-link-insert ()
  (interactive)
  (insert "+0")
  (clmemo-inline-date-convert)
  (insert " "))

;
; rank
;
(defun clmemo-tag-rank-update ()
  (interactive)
  (beginning-of-line)
  (skip-chars-forward " \t")
  (when (looking-at "(rank: .+ #\\([0-9]+\\))")
    (let ((num (string-to-number (match-string 1))))
      (setq num (1+ num))
      (replace-match (concat "(rank: "
			     (format-time-string "[%Y-%m-%d] %H:%M:%S")
			     (format " #%d)" num))))))

(defun clmemo-tag-rank-insert ()
  (insert (format-time-string "[%Y-%m-%d] %H:%M:%S #1")))

;;
;; list
;;
(defun clmemo-get-item-header-text ()
  (save-excursion
    (clmemo-previous-item)
    (buffer-substring-no-properties (point) (progn (end-of-line) (point)))))

(defun clmemo-list-link ()
  (interactive)
  (let (link list alist)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^\t(link: \\(.+\\))" nil t)
	(setq link (match-string 1))
	(unless (assoc link alist)
	  (setq alist (cons (cons link (clmemo-get-item-header-text)) alist)))))
    (setq list (mapcar (lambda (cc) (concat (car cc) "\t" (cdr cc))) alist))
    (setq list (nreverse list))
    (clmemo-list-create-buffer list "link"))
  (clmemo-list-mode))

(defvar clmemo-calc-rank-function
  #'(lambda (rank time-diff)
      (* 100 (/ rank (log time-diff)))))

(defun clmemo-list-rank ()
  (interactive)
  (let ((now (current-time))
	cc rank time ttme rating alist list)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^\t(rank: \\(.+\\) #\\([0-9]+\\))" nil t)
	(setq time (match-string 1)
	      ttme (apply 'encode-time (parse-time-string time))
	      rank (string-to-number (match-string 2))
	      rating (funcall clmemo-calc-rank-function
			      rank (time-to-seconds (time-subtract now ttme))))
	(setq cc (cons rating (format "%s  %s" time (clmemo-get-item-header-text)))
	      alist (cons cc alist))))
    (setq alist (sort alist (lambda (c1 c2) (< (car c2) (car c1)))))
    (setq list (mapcar (lambda (cc) (format "%4.2f  %s" (car cc) (cdr cc))) alist))
    (clmemo-list-create-buffer list "rank"))
  (clmemo-list-mode))

(defun clmemo-list-rank-date ()
  (interactive)
  (let (cc alist list)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^\t(rank: \\(.+ #[0-9]+\\))" nil t)
	(setq cc (cons (match-string 1) (clmemo-get-item-header-text))
	      alist (cons cc alist))))
    (setq alist (sort alist (lambda (c1 c2) (string< (car c2) (car c1)))))
    (setq list (mapcar (lambda (cc) (concat (car cc) "  " (cdr cc))) alist))
    (clmemo-list-create-buffer list "rank-date"))
  (clmemo-list-mode))

(defun clmemo-list-rank-num ()
  (interactive)
  (let (cc num alist list)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^\t(rank: \\(.+\\) #\\([0-9]+\\))" nil t)
	(setq cc (cons (format "%04d %s" (string-to-number (match-string 2))
			       (match-string 1))
		       (clmemo-get-item-header-text))
	      alist (cons cc alist))))
    (setq alist (sort alist (lambda (c1 c2) (string< (car c2) (car c1)))))
    (setq list (mapcar (lambda (cc) (concat (car cc) "  " (cdr cc))) alist))
    (clmemo-list-create-buffer list "rank-num"))
  (clmemo-list-mode))

(defun clmemo-list-create-buffer (list buf)
  (pop-to-buffer (concat "*clmemo-" buf "*"))
  (delete-region (point-min) (point-max))
  (insert (format "  ==%s==\n\n" buf))
  (insert (mapconcat (lambda (elt) elt) list "\n"))
  (goto-char (point-min)))

;
; clmemo-list-mode
;
(defvar clmemo-list-mode-map nil)
(if clmemo-list-mode-map
    nil
  (let ((map (make-keymap)))
    (define-key map " " 'clmemo-list-show)
    (define-key map "n" 'clmemo-list-next-item)
    (define-key map "p" 'clmemo-list-previous-item)
    (define-key map "q" 'delete-window)
    (setq clmemo-list-mode-map map)))

(define-derived-mode clmemo-list-mode text-mode "clmemo:list"
  "Major mode for clmemo-list.
\\{clmemo-list-map}")

(defun clmemo-list-next-item (arg)
  (interactive "p")
  (clmemo-list-show arg))

(defun clmemo-list-previous-item (arg)
  (interactive "p")
  (clmemo-list-show (- arg)))

(defun clmemo-list-show (&optional arg)
  "Show the item."
  (interactive)
  (let ((buf (current-buffer)) tag)
    (if arg
	(forward-line arg)
      (beginning-of-line))
    (skip-chars-forward "^*")
    (save-excursion
      (let ((end (progn (skip-chars-backward " \t") (point))))
	(beginning-of-line)
	(when (search-forward "[" nil t)
	  (backward-char 1)
	  (setq tag (buffer-substring-no-properties (point) end)))))
    (unwind-protect
	(progn
	  (switch-to-buffer-other-window
	   (or (get-file-buffer clmemo-file-name)
	       (find-file-noselect clmemo-file-name)))
	  (goto-char (point-min))
	  (search-forward tag)
	  (clmemo-previous-item 1))
      (pop-to-buffer buf))))


;;
;; Header with/out weekday
;;
(defun add-log-iso8601-time-string-with-weekday (&optional time zone)
  ;; Code contributed from Satoru Takabayashi <satoru@namazu.org>
  (let ((system-time-locale "C"))
    (concat (add-log-iso8601-time-string)
            " (" (format-time-string "%a") ")")))

(defun clmemo-format-header-with-weekday (beg end)
  "Format ChangeLog header with weekday
FROM: 2001-01-01  ataka
TO:   2001-01-01 (Mon)  ataka

See also function `clmemo-format-header-without-weekday'."
  (interactive "*r")
  (let* ((system-time-locale "C")
	 date weekday)
    (save-excursion
      (goto-char end)
      (while (re-search-backward "^\\([-0-9]+\\)" beg t)
	(save-match-data
	  (setq date    (match-string 0)
		weekday (format-time-string "%a" (date-to-time (concat date " 0:0:0")))))
	(replace-match (concat date " (" weekday ")"))
	(beginning-of-line)))))

(defun clmemo-format-header-without-weekday (beg end)
  "Format ChangeLog header without weekday
FROM:   2001-01-01 (Mon)  ataka
TO:     2001-01-01  ataka

See also function `clmemo-format-header-with-weekday'."
  (interactive "*r")
  (save-excursion
    (goto-char end)
    (while (re-search-backward "^\\([-0-9]+\\) (.+)" beg t)
      (replace-match "\\1")
      (beginning-of-line))))


;;
;; clgrep mode
;;
(defun clmemo-grep (arg)
  "Switch to ChangeLog Memo and grep it immediately."
  ;; Ask query before switching buffer and set QUERY non-nil if the
  ;; value of variable clmemo-grep-function is 'clgrep.
  (let ((query (and (fboundp clmemo-grep-function)
		    (eq clmemo-grep-function 'clgrep)
		    (read-string "clgrep: ")))
	(window (current-window-configuration)))
    (switch-to-buffer (find-file-noselect clmemo-file-name))
    (clmemo-mode)
    (cond
     ;; clmemo-grep-function is clgrep
     ;; FIXME  I don't understand the usage of condition-case.
     (query (condition-case nil
	        (funcall clmemo-grep-function query arg)
	      (error (set-window-configuration window)
		     (error "No matches for `%s'" query))))
     ;; clmemo-grep-function is available
     ((fboundp clmemo-grep-function)
      (let ((current-prefix-arg arg))
	(call-interactively clmemo-grep-function)))
     ;; Otherwise
     (t
      (let ((current-prefix-arg nil))
	(call-interactively 'occur))))))


(provide 'clmemo)

;;; clmemo.el ends here

;; Local Variables:
;; fill-column: 72
;; coding: utf-8
;; End:
