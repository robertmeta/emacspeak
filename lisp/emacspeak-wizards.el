;;; emacspeak-wizards.el --- Magic -*- lexical-binding: t; -*-
;;
;; $Author: tv.raman.tv $
;; Description:  Contains convenience wizards
;; Keywords: Emacspeak,  Audio Desktop Wizards
;;;   LCD Archive entry:

;; LCD Archive Entry:
;; emacspeak| T. V. Raman |tv.raman.tv@gmail.com
;; A speech interface to Emacs |
;;
;;  $Revision: 4638 $ |
;; Location https://github.com/tvraman/emacspeak
;;

;;;   Copyright:

;; Copyright (C) 1995 -- 2024, T. V. Raman
;; Copyright (c) 1994, 1995 by Digital Equipment Corporation.
;; All Rights Reserved.
;;
;; This file is not part of GNU Emacs, but the same permissions apply.
;;
;; GNU Emacs is free software; you can redistribute it and/or modify
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; Commentary:

;; Contains various wizards for the Emacspeak desktop.

;;; Code:

;;;   Required modules

(eval-when-compile
  (require 'cl-lib))
(require 'cl-extra)
(cl-declaim (optimize (safety 0) (speed 3)))
(eval-when-compile
  (require 'subr-x)
  (require 'derived)
  (require 'light)
  (require 'let-alist))
(require 'g-utils)
(require 'find-func)
(require 'comint)
(require 'shell)
(require 'dired)
(require 'org)
(require 'emacspeak-preamble)
(require 'emacspeak-we)
(require 'name-this-color "name-this-color" 'no-error )
(require 'color)
(eval-when-compile
  (require 'calendar)
  (require 'cus-edit)
  (require 'desktop)
  (require 'emacspeak-table-ui)
  (require 'emacspeak-xslt)
  (require 'find-dired)
  (require 'gweb)
  (require 'lisp-mnt)
  (require 'name-this-color "name-this-color" 'no-error)
  (require 'org)
  (require 'shell)
  (require 'solar)
  (require 'term)
  (require 'texinfo))
(require 'emacspeak-url-template)
(declare-function word-at-point "thingatpt" (&optional no-properties))
(declare-function sox-play "sox" t)

;;; Forward Decls:

(declare-function org-table-previous-row "emacspeak-org" nil)
(declare-function
 emacspeak-org-table-speak-current-element "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-coordinates "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-both-headers-and-element
                  "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-row-header-and-element
                  "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-column-header-and-element
                  "emacspeak-org" nil)
;;; Appease Emacs-30:

(declare-function iimage-recenter "iimage" (&optional arg))

;;; defgroup:
(defgroup emacspeak-wizards nil
  "Wizards for the Emacspeak desktop."
  :group 'emacspeak
  :prefix "emacspeak-wizards-")

;;; Read JSON file:

(defsubst ems--json-read-file (filename)
  "Use native json implementation if available to read json file."
  (cond
   ((fboundp 'json-parse-buffer)
    (with-current-buffer (find-file-noselect filename)
      (goto-char (point-min))
      (prog1
          (json-parse-buffer :object-type 'alist)
        (kill-buffer ))))
   (t (json-read-file filename))))

;;;   Emacspeak News and Documentation

;;;###autoload
(defun emacspeak-view-emacspeak-news ()
  "Display emacspeak News for a given version."
  (interactive)
  (cl-declare (special emacspeak-etc-directory))
  (find-file-read-only
   (expand-file-name
    (completing-read "News: "
                     (directory-files emacspeak-etc-directory nil "NEWS*"))
    emacspeak-etc-directory))
  (emacspeak-auditory-icon 'news)
  (org-mode)
  (org-next-visible-heading 1)
  (emacspeak-speak-line))

(defun emacspeak-view-emacspeak-tips ()
  "Browse  Emacspeak productivity tips."
  (interactive)
  (cl-declare (special emacspeak-etc-directory))
  (emacspeak-xslt-without-xsl
   (browse-url
    (format "file:///%stips.html"
            emacspeak-etc-directory)))
  (emacspeak-auditory-icon 'help)
  (emacspeak-speak-mode-line))

;;;  utility function to copy documents:

(defvar emacspeak-copy-file-location-history nil
  "History list for prompting for a copy location.")

(defvar emacspeak-copy-associated-location nil
  "Buffer local variable that records where we copied this document last.")

(make-variable-buffer-local
 'emacspeak-copy-associated-location)

(defun emacspeak-copy-current-file ()
  "Copy file visited in current buffer to new location.
Prompts for the new location and preserves modification time
  when copying.  If location is a directory, the file is copied
  to that directory under its current name ; if location names
  a file in an existing directory, the specified name is
  used.  Asks for confirmation if the copy will result in an
  existing file being overwritten."
  (interactive)
  (cl-declare (special emacspeak-copy-file-location-history
                       minibuffer-history
                       emacspeak-copy-associated-location))
  (let ((file (or (buffer-file-name)
                  (error "Current buffer is not visiting any file")))
        (location (read-file-name
                   "Copy current file to location: "
                   emacspeak-copy-associated-location ;default
                   (car
                    emacspeak-copy-file-location-history)))
        (minibuffer-history (or
                             emacspeak-copy-file-location-history
                             minibuffer-history)))
    (setq emacspeak-copy-associated-location location)
    (when (file-directory-p location)
      (unless
          (string-equal location (car emacspeak-copy-file-location-history))
        (push location emacspeak-copy-file-location-history))
      (setq location
            (expand-file-name
             (file-name-nondirectory file)
             location)))
    (copy-file
     file location
     1                                  ;prompt before overwriting
     t                                  ;preserve
                                        ;modification time
     )
    (emacspeak-auditory-icon 'select-object)
    (message "Copied current document to %s" location)))

(defun emacspeak-link-current-file ()
  "Link (hard link) file visited in current buffer to new location.
Prompts for the new location and preserves modification time
  when linking.  If location is a directory, the file is copied
  to that directory under its current name ; if location names
  a file in an existing directory, the specified name is
  used.  Signals an error if target already exists."
  (interactive)
  (cl-declare (special emacspeak-copy-file-location-history
                       emacspeak-copy-associated-location))
  (let ((file (or (buffer-file-name)
                  (error "Current buffer is not visiting any file")))
        (location (read-file-name
                   "Link current file to location: "
                   emacspeak-copy-associated-location ;default
                   (car
                    emacspeak-copy-file-location-history)))
        (minibuffer-history (or
                             emacspeak-copy-file-location-history
                             minibuffer-history)))
    (setq emacspeak-copy-associated-location location)
    (when (file-directory-p location)
      (unless
          (string-equal location (car emacspeak-copy-file-location-history))
        (push location emacspeak-copy-file-location-history))
      (setq location
            (expand-file-name
             (file-name-nondirectory file)
             location)))
    (add-name-to-file
     file location)
    (emacspeak-auditory-icon 'select-object)
    (message "Linked current document to %s" location)))

(defun emacspeak-symlink-current-file ()
  "Link (symbolic link) file visited in current buffer to new location.
Prompts for the new location and preserves modification time
  when linking.  If location is a directory, the file is copied
  to that directory under its current name ; if location names
  a file in an existing directory, the specified name is
  used.  Signals an error if target already exists."
  (interactive)
  (cl-declare (special emacspeak-copy-file-location-history
                       emacspeak-copy-associated-location))
  (let ((file (or (buffer-file-name)
                  (error "Current buffer is not visiting any file")))
        (location (read-file-name
                   "Symlink current file to location: "
                   emacspeak-copy-associated-location ;default
                   (car
                    emacspeak-copy-file-location-history)))
        (minibuffer-history (or
                             emacspeak-copy-file-location-history
                             minibuffer-history)))
    (setq emacspeak-copy-associated-location location)
    (when (file-directory-p location)
      (unless
          (string-equal location (car emacspeak-copy-file-location-history))
        (push location emacspeak-copy-file-location-history))
      (setq location
            (expand-file-name
             (file-name-nondirectory file)
             location)))
    (make-symbolic-link
     file location)
    (emacspeak-auditory-icon 'select-object)
    (message "Symlinked  current doc>ument to %s" location)))

;;;  pop up messages buffer

;;;###autoload
(defun emacspeak-speak-popup-messages ()
  "Pop up Messages  and switch to it."
  (interactive)
  (select-window (view-echo-area-messages))
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-read-previous-line))

(defvar emacspeak-speak-network-interfaces-list
  (ems--get-active-network-interfaces)
  "Used when prompting for an interface to query.")

;;;  Show active network interfaces

(defun emacspeak-speak-hostname ()
  "Speak host name."
  (interactive)
  (message (system-name)))

;;;  Elisp Utils:

(defun emacspeak-wizards-next-interactive-defun ()
  "Move point to the next interactive defun"
  (interactive)
  (end-of-defun)
  (re-search-forward "^ *(interactive")
  (beginning-of-defun)
  (emacspeak-speak-line))

;;;   simple phone book

(defcustom emacspeak-speak-telephone-directory
  (expand-file-name "tel-dir" emacspeak-user-directory)
  "File holding telephone directory.
This is just a text file, and we use grep to search it."
  :group 'emacspeak-speak
  :type 'string)

(defvar emacspeak-speak-telephone-directory-command
  "grep -i "
  "Command used to look up names in the telephone directory.")

;;;###autoload
(defun emacspeak-speak-telephone-directory (&optional edit)
  "Lookup and display a phone number.
With prefix arg, opens the phone book for editing."
  (interactive "P")
  (cond
   (edit
    (funcall-interactively #'find-file emacspeak-speak-telephone-directory))
   ((file-exists-p emacspeak-speak-telephone-directory)
    (emacspeak-shell-command
     (format "%s %s %s"
             emacspeak-speak-telephone-directory-command
             (read-from-minibuffer "Lookup number for: ")
             emacspeak-speak-telephone-directory)))
   (t (error "First create your phone directory in %s"
             emacspeak-speak-telephone-directory))))

;;;  find file as root

;; http://emacs-fu.blogspot.com/
;; 2013/03/editing-with-root-privileges-once-more.html
;;;###autoload
(defun emacspeak-wizards-find-file-as-root (file)
  "Automatically edit file with root-privileges (using
tramp/sudo), if the file is not writable by user."
  (interactive
   (list
    (cond
     ((eq major-mode 'dired-mode) (dired-file-name-at-point))
     (t (ido-read-file-name "Edit as root: ")))))
  (unless (file-writable-p file)
    (setq file (concat "/sudo:root@localhost:" file)))
  (find-file file)
  (when (called-interactively-p 'interactive)
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))

;;;  browse chunks

(defun emacspeak-wizards-move-and-speak (command count)
  "Speaks a chunk of text bounded by point and a target position.
Target position is specified using a navigation command and a
count that specifies how many times to execute that command
first.  Point is left at the target position.  Interactively,
command is specified by pressing the key that invokes the
command."
  (interactive
   (list
    (lookup-key global-map
                (read-key-sequence "Key:"))
    (read-minibuffer "Count:")))
  (let ((orig (point)))
    (push-mark orig)
    (funcall command count)
    (emacspeak-speak-region orig (point))))

;;;   Learn mode

;;;###autoload
(defun emacspeak-learn-emacs ()
  "Helps you learn the keys.  You can press keys and hear what they do.
To leave, press \\[keyboard-quit]."
  (interactive)
  (ems-with-messages-silenced
   (let ((continue t))
     (while continue
       (call-interactively 'describe-key-briefly)
       (sit-for 4)
       (when (and (numberp last-input-event)
                  (= last-input-event 7))
         (setq continue nil)))
     (message "Leaving learn mode "))))

(defun emacspeak-describe-emacspeak ()
  "Give a brief overview of emacspeak."
  (interactive)
  (describe-function 'emacspeak)
  (switch-to-buffer "*Help*")
  (dtk-set-punctuations 'all)
  (emacspeak-speak-buffer))

;;;  Frame Nav:

;;;###autoload
(defun emacspeak-next-frame-or-buffer (&optional frame)
  "Move to next buffer.
With optional interactive prefix arg `frame', move to next frame instead."
  (interactive "P")
  (cond
   (frame (funcall-interactively #'other-frame 1))
   (t (call-interactively #'next-buffer))))

;;;###autoload
(defun emacspeak-previous-frame-or-buffer (&optional frame)
  "Move to previous buffer.
With optional interactive prefix arg `frame', move to previous frame instead."
  (interactive "P")
  (cond
   (frame (funcall-interactively #'other-frame -1))
   (t (call-interactively #'previous-buffer))))

;;;   readng different displays of same buffer

;;;###autoload
(defun emacspeak-speak-this-buffer-other-window-display ( window)
  "Speak this buffer as displayed in a different frame or window.  Emacs
allows you to display the same buffer in multiple windows or
frames.  These different windows can display different
portions of the buffer.  This is equivalent to leaving a
book open at places at once.  This command allows you to
listen to the places where you have left the book open.  "
  (interactive (list (read-number "Frame Or Window: " 0)))
  (let ((win nil)
        (window-list (get-buffer-window-list (current-buffer) nil 'visible)))
    (or (numberp window)
        (setq window
              (read-minibuffer "Display    to speak")))
    (setq win (nth (% window (length window-list)) window-list))
    (save-excursion
      (save-window-excursion
        (emacspeak-speak-region
         (window-point win)
         (window-end win 'update))))))

;;;###autoload
(defun emacspeak-speak-this-buffer-previous-display ()
  "Speak this buffer as displayed in a `previous' window.
See documentation for command
`emacspeak-speak-this-buffer-other-window-display' for the
meaning of `previous'."
  (interactive)
  (let ((count (length (get-buffer-window-list
                        (current-buffer)
                        nil 'visible))))
    (emacspeak-speak-this-buffer-other-window-display (1- count))))
;;;###autoload
(defun emacspeak-speak-this-buffer-next-display ()
  "Speak this buffer as displayed in a `previous' window.
See documentation for command
`emacspeak-speak-this-buffer-other-window-display' for the
meaning of `next'."
  (interactive)
  (emacspeak-speak-this-buffer-other-window-display 1))

(defun emacspeak-select-this-buffer-other-window-display (&optional arg)
  "Switch to this buffer as displayed in a different frame.
Emacs allows you to display the same buffer in multiple windows
or frames.  These different windows can display different
portions of the buffer.  This is equivalent to leaving a book
open at multiple places at once.  "
  (interactive "P")
  (let ((window
         (or arg
             (condition-case nil
                 (read (format "%c" last-input-event))
               (error nil))))
        (win nil)
        (window-list (get-buffer-window-list
                      (current-buffer)
                      nil 'visible)))
    (or (numberp window)
        (setq window
              (read-minibuffer "Display to select")))
    (setq win
          (nth (% window (length window-list))
               window-list))
    (select-frame (window-frame win))
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'select-object)))
;;;###autoload
(defun emacspeak-select-this-buffer-previous-display ()
  "Select this buffer as displayed in a `previous' window.
See documentation for command
`emacspeak-select-this-buffer-other-window-display' for the
meaning of `previous'."
  (interactive)
  (let ((count (length (get-buffer-window-list
                        (current-buffer)
                        nil 'visible))))
    (emacspeak-select-this-buffer-other-window-display (1- count))))
;;;###autoload
(defun emacspeak-select-this-buffer-next-display ()
  "Select this buffer as displayed in a `next' frame.
See documentation for command
`emacspeak-select-this-buffer-other-window-display' for the
meaning of `next'."
  (interactive)
  (emacspeak-select-this-buffer-other-window-display 1))

;;;   Display properties conveniently

;; Useful for developing emacspeak:
;; Display selected properties of interest

(defvar emacspeak-property-table
  '(("personality" . "personality")
    ("auditory-icon" . "auditory-icon")
    ("action" . "action"))
  "Properties emacspeak is interested in.")

;;;###autoload
(defun emacspeak-show-style-at-point ()
  "Show value of property personality (and possibly face) at point."
  (interactive)
  (let ((f (get-text-property (point) 'face))
        (style (dtk-get-style))
        (msg nil))
    (setq msg
          (concat
           (propertize
            (format "%s" (or style "No Style "))
            'personality style )
           (when f
             (concat
              " for "
              (propertize
               (format "%s" (or f ""))
               'face f)))))
    (message msg)))

;;;###autoload
(defun emacspeak-show-property-at-point (&optional property)
  "Show value of PROPERTY at point.
If optional arg property is not supplied, read it interactively. "
  (interactive
   (let
       ((properties (text-properties-at (point))))
     (cond
      ((and properties
            (= 2 (length properties)))
       (list (car properties)))
      (properties
       (list
        (intern
         (completing-read
          "Display property: "
          (cl-loop
           for p in properties and i from 0 if (cl-evenp i) collect p)))))
      (t (message "No property set at point ")
         nil))))
  (if property
      (kill-new
       (message "%s"
                (get-text-property (point) property)))))

;;;   moving across blank lines

;;;###autoload
(defun emacspeak-skip-blank-lines-forward ()
  "Move forward across blank lines, then speak line.
"
  (interactive)
  (let ((save-syntax (char-syntax 10))
        (start (point))
        (newlines nil)
        (skipped nil)
        (skip 0))
    (unwind-protect
        (progn
          (modify-syntax-entry 10 " ")
          (end-of-line)
          (setq skip (skip-syntax-forward " "))
          (cond
           ((zerop skip)
            (message "Did not move "))
           ((eobp)
            (message "At end of buffer"))
           (t
            (beginning-of-line)
            (setq newlines (1- (count-lines start (point))))
            (when (> newlines 0)
              (setq skipped
                    (format "skip %d " newlines))
              (put-text-property 0 (length skipped)
                                 'personality
                                 voice-annotate skipped))
            (emacspeak-auditory-icon 'select-object)
            (dtk-speak
             (concat skipped (ems--this-line))))))
      (modify-syntax-entry 10 (format "%c" save-syntax)))))
;;;###autoload
(defun emacspeak-skip-blank-lines-backward ()
  "Move backward  across blank lines, then speak line. "
  (interactive)
  (let ((save-syntax (char-syntax 10))
        (newlines nil)
        (start (point))
        (skipped nil)
        (skip 0))
    (unwind-protect
        (progn
          (modify-syntax-entry 10 " ")
          (beginning-of-line)
          (setq skip (skip-syntax-backward " "))
          (cond
           ((zerop skip)
            (message "Did not move "))
           ((bobp)
            (message "At start  of buffer"))
           (t
            (beginning-of-line)
            (setq newlines (1- (count-lines start (point))))
            (when (> newlines 0)
              (setq skipped (format "skip %d " newlines))
              (put-text-property 0 (length skipped)
                                 'personality
                                 voice-annotate skipped))
            (emacspeak-auditory-icon 'select-object)
            (dtk-speak
             (concat skipped (ems--this-line))))))
      (modify-syntax-entry 10 (format "%c" save-syntax)))))

;;; Moving across spaces:
;;;###autoload
(defun emacspeak-skip-space-forwar ()
  "Skip forward across blanks."
  (interactive)
  (dtk-notify-say  (skip-syntax-forward " "))
  (emacspeak-speak-char t))

;;;###autoload
(defun emacspeak-skip-space-backward ()
  "Skip back across blanks."
  (interactive)
  (dtk-notify-say  (skip-syntax-backward " "))
  (emacspeak-speak-preceding-char))

;;;  ansi term

;;;  shell-toggle

;; inspired by eshell-toggle
;; switch to the shell buffer, and cd to the directory
;; that is the default-directory for the previously current
;; buffer.
;;;###autoload
(defun emacspeak-wizards-shell-toggle ()
  "Switch to  shell  and cd to
  directory of the previously current buffer."
  (interactive)
  (cl-declare (special default-directory))
  (let ((dir default-directory))
    (shell)
    (unless (string-equal (expand-file-name dir)
                          (expand-file-name default-directory))
      (shell-cd dir))
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-mode-line)))

;;;  pdf wizard

(defvar emacspeak-wizards-pdf-to-text-program
  "pdftotext"
  "Command for running pdftotext.")

(defcustom emacspeak-wizards-pdf-to-text-options
  "-layout"
  "options to Command for running pdftotext."
  :type '(choice
          (const :tag "None" nil)
          (string :tag "Options" "-layout"))
  :group 'emacspeak-wizards)

(defun emacspeak-wizards-pdf-open (filename &optional ask-pwd)
  "Open pdf file as text.
Optional interactive prefix arg ask-pwd prompts for password."
  (interactive
   (list
    (let ((completion-ignored-extensions nil))
      (expand-file-name
       (read-file-name
        "PDF File: "
        nil default-directory
        t nil
        #'(lambda (f) (string-match "\\.pdf$" f)))))
    current-prefix-arg))
  (cl-declare (special emacspeak-wizards-pdf-to-text-options
                       emacspeak-wizards-pdf-to-text-program))
  (cl-assert (string-match ".pdf$"filename) t "Not a PDF file.")
  (let ((passwd (when ask-pwd (read-passwd "User Password:")))
        (output-buffer
         (format "%s"
                 (file-name-sans-extension
                  (file-name-nondirectory filename)))))
    (shell-command
     (format
      "%s %s %s  %s - | cat -s "
      emacspeak-wizards-pdf-to-text-program
      emacspeak-wizards-pdf-to-text-options
      (if passwd
          (format "-opw %s -upw %s" passwd passwd)
        "")
      (shell-quote-argument
       (expand-file-name filename)))
     output-buffer)
    (switch-to-buffer output-buffer)
    (set-buffer-modified-p nil)
    (text-mode)
    (view-mode)
    (emacspeak-speak-mode-line)
    (emacspeak-auditory-icon 'open-object)))

;;;  tramp wizard

(defcustom emacspeak-wizards-tramp-locations nil
  "Tramp locations used by Emacspeak tramp wizard.
Locations added here via custom can be opened using command
emacspeak-wizards-tramp-open-location
bound to \\[emacspeak-wizards-tramp-open-location]."
  :type '(repeat
          (cons :tag "Tramp"
                (string :tag "Name")
                (string :tag "Location")))
  :group 'emacspeak-wizards)

;;;###autoload
(defun emacspeak-wizards-tramp-open-location (name)
  "Open specified tramp location.
Location is specified by name."
  (interactive
   (list
    (let ((completion-ignore-case t))
      (completing-read
       "Location:"
       emacspeak-wizards-tramp-locations nil 'must-match))))
  (cl-declare (special emacspeak-wizards-tramp-locations))
  (let ((location (cdr (assoc name emacspeak-wizards-tramp-locations))))
    (find-file  location)))

;;;  customize emacspeak

(declare-function emacspeak-custom-goto-group "emacspeak-custom" nil)

;;;###autoload
(defun emacspeak-customize ()
  "Customize Emacspeak."
  (interactive)
  (customize-group 'emacspeak)
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-custom-goto-group))

;;;  squeeze blank lines in current buffer:
;;;###autoload
(defun emacspeak-wizards-squeeze-blanks (start end)
  "Squeeze multiple blank lines."
  (interactive "r")
  (shell-command-on-region start end
                           "cat -s"
                           (current-buffer)
                           'replace)
  (indent-region (point-min) (point-max))
  (untabify (point-min) (point-max))
  (delete-trailing-whitespace))

;;;   count slides in region: (LaTeX specific.

(defun emacspeak-wizards-count-slides-in-region (start end)
  "Count slides starting from point."
  (interactive "r")
  (how-many "begin\\({slide}\\|{part}\\)"
            start end 'interactive))

;;;   file specific  headers via occur

(defvar emacspeak-occur-pattern nil
  "Regexp pattern used to identify header lines by command
emacspeak-wizards-occur-header-lines.")
(make-variable-buffer-local 'emacspeak-occur-pattern)
;;;###autoload
(defun emacspeak-wizards-how-many-matches (start end &optional prefix)
  "If you define a file local variable
called `emacspeak-occur-pattern' that holds a regular expression
that matches  lines of interest, you can use this command to
run `how-many' to count  matching header lines.
With interactive prefix arg, prompts for and remembers the file local pattern."
  (interactive
   (list
    (point)
    (mark)
    current-prefix-arg))
  (cl-declare (special emacspeak-occur-pattern))
  (cond
   ((and (not prefix)
         (boundp 'emacspeak-occur-pattern)
         emacspeak-occur-pattern)
    (how-many emacspeak-occur-pattern start end 'interactive))
   (t
    (let ((pattern (read-from-minibuffer "Regular expression: ")))
      (setq emacspeak-occur-pattern pattern)
      (how-many pattern start end 'interactive)))))

;;;###autoload
(defun emacspeak-wizards-occur-header-lines (&optional prefix)
  "If you define a file local variable called
`emacspeak-occur-pattern' that holds a regular expression that
matches header lines, you can use this command to
run `occur' to find matching header lines. With prefix arg,
prompts for and sets value of the file local pattern."
  (interactive "P")
  (cl-declare (special emacspeak-occur-pattern))
  (cond
   ((and (not prefix)
         (boundp 'emacspeak-occur-pattern)
         emacspeak-occur-pattern)
    (occur emacspeak-occur-pattern)
    (message "Displayed header lines in other window.")
    (emacspeak-auditory-icon 'open-object))
   (t
    (let ((pattern (read-from-minibuffer "Regular expression: ")))
      (setq emacspeak-occur-pattern pattern)
      (occur pattern)))))

;;;    Switching buffers, killing buffers etc

;;;###autoload
(defun emacspeak-kill-buffer-quietly ()
  "Kill current buffer without  confirmation."
  (interactive)
  (kill-buffer nil)
  (when (called-interactively-p 'interactive)
    (emacspeak-auditory-icon 'close-object)
    (emacspeak-speak-mode-line)))

;;;  VC viewer
(defvar emacspeak-wizards-vc-viewer-command
  "setterm -dump %s -file %s"
  "Command line for dumping out virtual console.  Make sure you have
access to /dev/vcs* by adding yourself to the appropriate group.  On
Ubuntu and Debian this is group `tty'.")

(define-derived-mode emacspeak-wizards-vc-view-mode special-mode
  "VC Viewer  Interaction"
  "Major mode for interactively viewing virtual console contents.\n\n
\\{emacspeak-wizards-vc-view-mode-map}")

(defvar emacspeak-wizards-vc-console nil
  "Buffer local value specifying console we are viewing.")

(make-variable-buffer-local 'emacspeak-wizards-vc-console)

;;;###autoload
(defun emacspeak-wizards-vc-viewer (console)
  "View contents of  virtual console."
  (interactive "nConsole:")
  (cl-declare (special emacspeak-wizards-vc-viewer-command
                       emacspeak-wizards-vc-console
                       temporary-file-directory))
  (ems-with-messages-silenced
   (let ((command
          (format emacspeak-wizards-vc-viewer-command
                  console
                  (expand-file-name
                   (format "vc-%s.dump" console)
                   temporary-file-directory)))
         (buffer (get-buffer-create
                  (format "*vc-%s*" console))))
     (shell-command command buffer)
     (switch-to-buffer buffer)
     (kill-all-local-variables)
     (insert-file-contents
      (expand-file-name
       (format "vc-%s.dump" console)
       temporary-file-directory))
     (set-buffer-modified-p nil)
     (emacspeak-wizards-vc-view-mode)
     (setq emacspeak-wizards-vc-console console)
     (goto-char (point-min))
     (when (called-interactively-p 'interactive) (emacspeak-speak-line)))))

(defun emacspeak-wizards-vc-viewer-refresh ()
  "Refresh view of VC we're viewing."
  (interactive)
  (cl-declare (special emacspeak-wizards-vc-console))
  (unless (eq major-mode
              'emacspeak-wizards-vc-view-mode)
    (error "Not viewing a virtual console."))
  (let ((console emacspeak-wizards-vc-console)
        (command
         (format emacspeak-wizards-vc-viewer-command
                 emacspeak-wizards-vc-console
                 (expand-file-name
                  (format "vc-%s.dump"
                          emacspeak-wizards-vc-console)
                  temporary-file-directory)))
        (inhibit-read-only t)
        (orig (point)))
    (shell-command command)
    (fundamental-mode)
    (erase-buffer)
    (insert-file-contents
     (expand-file-name
      (format "vc-%s.dump"
              console)
      temporary-file-directory))
    (set-buffer-modified-p nil)
    (goto-char orig)
    (emacspeak-wizards-vc-view-mode)
    (setq emacspeak-wizards-vc-console console)
    (when (called-interactively-p 'interactive)
      (emacspeak-speak-line))))

(defun emacspeak-wizards-vc-n ()
  "Accelerator for VC viewer."
  (interactive)
  (cl-declare (special last-input-event))
  (emacspeak-wizards-vc-viewer (format "%c" last-input-event))
  (emacspeak-speak-line)
  (emacspeak-auditory-icon 'open-object))

(cl-declaim (special emacspeak-wizards-vc-view-mode-map))

(define-key emacspeak-wizards-vc-view-mode-map
            "\C-l" 'emacspeak-wizards-vc-viewer-refresh)

;;;  longest line in region
;;;###autoload
(defun emacspeak-wizards-find-longest-line-in-region (start end)
  "Find longest line in region and move to it. "
  (interactive "r")
  (let ((max 0)
        (where nil))
    (save-excursion
      (goto-char start)
      (while (and (not (eobp))
                  (< (point) end))
        (when
            (< max
               (- (line-end-position)
                  (line-beginning-position)))
          (setq max (- (line-end-position)
                       (line-beginning-position)))
          (setq where (line-beginning-position)))
        (forward-line 1)))
    (when (called-interactively-p 'interactive)
      (message "Longest line is %s columns"
               max)
      (goto-char where))
    max))

(defun emacspeak-wizards-find-shortest-line-in-region (start end)
  "Find shortest line in region.
Moves to the shortest line when called interactively."
  (interactive "r")
  (let ((min 1)
        (where (point)))
    (save-excursion
      (goto-char start)
      (while (and (not (eobp))
                  (< (point) end))
        (when
            (< (- (line-end-position)
                  (line-beginning-position))
               min)
          (setq min (- (line-end-position)
                       (line-beginning-position)))
          (setq where (line-beginning-position)))
        (forward-line 1)))
    (when (called-interactively-p 'interactive)
      (message "Shortest line is %s columns"
               min)
      (goto-char where))
    min))

;;;  longest para in region
;;;###autoload
(defun emacspeak-wizards-find-longest-paragraph-in-region (start end)
  "Find longest paragraph in region, and move to it. "
  (interactive "r")
  (let ((max 0)
        (where nil)
        (para-start start))
    (save-excursion
      (goto-char start)
      (while (and (not (eobp))
                  (< (point) end))
        (forward-paragraph 1)
        (when
            (< max (- (point) para-start))
          (setq max (- (point) para-start))
          (setq where para-start))
        (setq para-start (point))))
    (when (called-interactively-p 'interactive)
      (message "Longest paragraph is %s characters"
               max)
      (goto-char where))
    max))

;;;  face wizard
;;;###autoload
(defun emacspeak-wizards-show-face (face)
  "Show  properties of  face."
  (interactive
   (list
    (read-face-name "Face")))
  (let ((output (get-buffer-create "*emacspeak-face-display*")))
    (save-current-buffer
      (set-buffer output)
      (setq buffer-read-only nil)
      (erase-buffer)
      (insert (format "Face: %s\n" face))
      (cl-loop for a in
               (mapcar #'car face-attribute-name-alist)
               do
               (unless (eq 'unspecified (face-attribute face a))
                 (insert
                  (format "%s\t%s\n"
                          a
                          (face-attribute face a)))))
      (insert
       (format "Documentation: %s\n"
               (face-documentation face)))
      (setq buffer-read-only t))
    (when (called-interactively-p 'interactive)
      (switch-to-buffer output)
      (goto-char (point-min))
      (emacspeak-speak-mode-line)
      (emacspeak-auditory-icon 'open-object))))

;;;  ISO dates
;; implementation based on icalendar.el

;;;###autoload
(defun emacspeak-wizards-speak-iso-datetime (iso)
  "Speak ISO date-time."
  (interactive
   (list
    (read-from-minibuffer "ISO DateTime:"
                          (word-at-point))))
  (ems-with-messages-silenced
   (let ((time (emacspeak-pronounce-decode-iso-datetime iso)))
     (tts-with-punctuations 'some (dtk-speak time))
     (message time))))

;;;  date pronouncer wizard
(defvar emacspeak-wizards-mm-dd-yyyy-date-pronounce nil
  "Toggled by wizard to record how we are pronouncing mm-dd-yyyy
dates.")

;;;###autoload
(defun emacspeak-wizards-toggle-mm-dd-yyyy-date-pronouncer ()
  "Toggle pronunciation of mm-dd-yyyy dates."
  (interactive)
  (cl-declare (special emacspeak-wizards-mm-dd-yyyy-date-pronounce
                       emacspeak-pronounce-date-mm-dd-yyyy-pattern))
  (cond
   (emacspeak-wizards-mm-dd-yyyy-date-pronounce
    (setq emacspeak-wizards-mm-dd-yyyy-date-pronounce nil)
    (emacspeak-pronounce-remove-buffer-local-dictionary-entry
     emacspeak-pronounce-date-mm-dd-yyyy-pattern))
   (t (setq emacspeak-wizards-mm-dd-yyyy-date-pronounce t)
      (emacspeak-pronounce-add-buffer-local-dictionary-entry
       emacspeak-pronounce-date-mm-dd-yyyy-pattern
       (cons #'re-search-forward
             'emacspeak-pronounce-mm-dd-yyyy-date))))
  (message "Will %s pronounce mm-dd-yyyy date strings in
  English."
           (if emacspeak-wizards-mm-dd-yyyy-date-pronounce "" "
  not ")))

(defvar emacspeak-wizards-yyyy-mm-dd-date-pronounce nil
  "Toggled by wizard to record how we are pronouncing yyyy-mm-dd
  dates.")

(defun emacspeak-wizards-toggle-yyyy-mm-dd-date-pronouncer ()
  "Toggle pronunciation of yyyy-mm-dd dates."
  (interactive)
  (cl-declare (special emacspeak-wizards-yyyy-mm-dd-date-pronounce
                       emacspeak-pronounce-date-yyyy-mm-dd-pattern))
  (cond
   (emacspeak-wizards-yyyy-mm-dd-date-pronounce
    (setq emacspeak-wizards-yyyy-mm-dd-date-pronounce nil)
    (emacspeak-pronounce-remove-buffer-local-dictionary-entry
     emacspeak-pronounce-date-yyyy-mm-dd-pattern))
   (t (setq emacspeak-wizards-yyyy-mm-dd-date-pronounce t)
      (emacspeak-pronounce-add-buffer-local-dictionary-entry
       emacspeak-pronounce-date-yyyy-mm-dd-pattern
       (cons #'re-search-forward
             'emacspeak-pronounce-yyyy-mm-dd-date))))
  (message "Will %s pronounce yyyy-mm-dd date strings in
  English."
           (if emacspeak-wizards-yyyy-mm-dd-date-pronounce
               "" " not ")))

(defvar emacspeak-wizards-yyyymmdd-date-pronounce nil
  "Toggled by wizard to record how we are pronouncing yyyymmdd dates.")

;;;###autoload
(defun emacspeak-wizards-toggle-yyyymmdd-date-pronouncer ()
  "Toggle pronunciation of yyyymmdd  dates."
  (interactive)
  (cl-declare (special emacspeak-wizards-yyyymmdd-date-pronounce
                       emacspeak-pronounce-date-yyyymmdd-pattern))
  (cond
   (emacspeak-wizards-yyyymmdd-date-pronounce
    (setq emacspeak-wizards-yyyymmdd-date-pronounce nil)
    (emacspeak-pronounce-remove-buffer-local-dictionary-entry
     emacspeak-pronounce-date-yyyymmdd-pattern))
   (t (setq emacspeak-wizards-yyyymmdd-date-pronounce t)
      (emacspeak-pronounce-add-buffer-local-dictionary-entry
       emacspeak-pronounce-date-yyyymmdd-pattern
       (cons 're-search-forward
             'emacspeak-pronounce-yyyymmdd-date))))
  (message "Will %s pronounce YYYYMMDD date strings in
  English."
           (if emacspeak-wizards-yyyymmdd-date-pronounce "" "
  not ")))

;;;  units wizard

;;;###autoload
(defun emacspeak-wizards-units ()
  "Run units."
  (interactive)
  (cl-declare (special emacspeak-comint-autospeak))
  (with-environment-variables
      (("PAGER" "cat"))
    (make-comint "units" (executable-find "units") nil "--verbose"))
  (switch-to-buffer "*units*")
  (emacspeak-auditory-icon 'select-object)
  (goto-char (point-max))
  (unless emacspeak-comint-autospeak
    (emacspeak-toggle-inaudible-or-comint-autospeak))
  (emacspeak-speak-mode-line))

;;;  shell history:

;;;  Organizing Shells: next, previous, tag

(defun ems--shell-pushd-if-needed (dir target)
  "Helper: execute pushd in shell `target' if needed."
  (with-current-buffer target
    (unless (string= (expand-file-name dir) default-directory)
      (goto-char (point-max))
      (insert (format "pushd %s" dir))
      (comint-send-input)
      (shell-process-pushd dir))))

(defun emacspeak-wizards-get-shells ()
  "Return list of shell buffers."
  (cl-loop
   for b in (buffer-list)
   when (with-current-buffer b (eq major-mode 'shell-mode)) collect b))

(defun emacspeak-wizards-switch-shell (direction)
  "Switch to next/previous shell buffer.
Direction specifies previous/next."
  (let* ((shells (emacspeak-wizards-get-shells))
         (target nil))
    (cond
     ((> (length shells) 1)
      (when (> direction 0) (bury-buffer))
      (setq target
            (if (> direction 0)
                (cl-second shells)
              (nth (1- (length shells)) shells)))
      (funcall-interactively #'switch-to-buffer target))
     ((= 1 (length shells)) (shell "1-shell"))
     (t (call-interactively #'shell)))))

;;;###autoload
(defun emacspeak-wizards-shell (&optional prefix)
  "Run Emacs  `shell' command when not in a shell buffer, or
when called with a prefix argument. When called from a shell buffer,
switches to `next' shell buffer. When called from outside a shell
buffer, find the most `appropriate shell' and switch to it. Once
switched, set default directory in that target shell to the directory
of the source buffer."
  (interactive "P")
  (cl-declare (special emacspeak-wizards--project-shell-directory))
  (cond
   ((or prefix (not (eq major-mode 'shell-mode)))
    (let ((dir default-directory)
          (shells (emacspeak-wizards-get-shells))
          (target nil)
          (target-len 0))
      (cl-loop
       for s in shells do
       (let ((sd
              (with-current-buffer s
                (expand-file-name
                 emacspeak-wizards--project-shell-directory))))
         (when
             (and
              (string-prefix-p sd dir)
              (> (length sd) target-len))
           (setq target s)
           (setq target-len (length sd)))))
      (cond
       (target (funcall-interactively #'switch-to-buffer target)
               (ems--shell-pushd-if-needed dir target))
       (t (call-interactively #'shell)))))
   (t (call-interactively 'emacspeak-wizards-cycle-to-next-buffer))))

;; Inspired by package project-shells from melpa --- but simplified.

(defvar emacspeak-wizards--shells-table (make-hash-table :test #'eq)
  "Table mapping live shell buffers to keys.")

(defun emacspeak-wizards--build-shells-table ()
  "Populate hash-table with live shell buffers."
  (cl-declare (special emacspeak-wizards--shells-table))
  ;; First, remove dead buffers
  (cl-loop
   for k being the hash-keys of emacspeak-wizards--shells-table
   unless (buffer-live-p (gethash k emacspeak-wizards--shells-table))
   do (remhash k emacspeak-wizards--shells-table))
  (let ((shells (emacspeak-wizards-get-shells))
        (v (hash-table-values emacspeak-wizards--shells-table)))
    ;; Add in live shells that are new
    (mapc
     #'(lambda (s)
         (when (not (memq s v))
           (puthash
            (hash-table-count emacspeak-wizards--shells-table)
            s emacspeak-wizards--shells-table)))
     shells)))

;;;###autoload
(defun emacspeak-wizards-shell-by-key (&optional prefix)
  "Switch to shell buffer by key. This provides a predictable
  means for switching to a specific shell buffer. When invoked
  from a non-shell-mode buffer that is a dired-buffer or is
  visiting a file, invokes `cd ' in the shell to change to the.
  value of `default-directory' When already in a shell buffer,
  interactive prefix arg `prefix' causes this shell to be
  re-keyed if appropriate --- see
  \\[emacspeak-wizards-shell-re-key] for an explanation of how
  re-keying works."
  (interactive "P")
  (cl-declare (special last-input-event emacspeak-wizards--shells-table
                       major-mode default-directory))
  (unless (emacspeak-wizards-get-shells) (shell))
  (emacspeak-wizards--build-shells-table)
  (cond
   ((and prefix (eq major-mode 'shell-mode))
    (emacspeak-wizards-shell-re-key
     (read (format "%c" last-input-event))
     (current-buffer)))
   (t
    (let* ((directory default-directory)
           (key
            (%
             (read (format "%c" last-input-event))
             (length (hash-table-keys emacspeak-wizards--shells-table))))
           (buffer (gethash key emacspeak-wizards--shells-table)))
      (when ;  source determines target directory
          (or (eq major-mode 'dired-mode) buffer-file-name)
        (unless prefix (ems--shell-pushd-if-needed directory buffer)))
      (funcall-interactively #'switch-to-buffer buffer)))))

(defcustom emacspeak-wizards-project-shells nil
  "Project shells, a list of shell-name/initial-directory pairs."
  :type '(repeat
          (list
           (string :tag "Buffer Name")
           (directory :tag "Directory")
           (boolean :tag "AutoSpeak")))
  :group 'emacspeak-wizards)

(defvar-local emacspeak-wizards--project-shell-directory "~/"
  "Default directory for a given project shell.")

;;;###autoload
(defun emacspeak-wizards-project-shells-initialize ()
  "Create shells per `emacspeak-wizards-project-shells'."
  (cl-declare (special emacspeak-wizards-project-shells))
  (unless emacspeak-wizards-project-shells (shell))
  (cl-loop
   for entry in (reverse emacspeak-wizards-project-shells) do
   (ems-with-messages-silenced
    (let* ((dtk-quiet t)
           (name (cl-first entry))
           (dir (cl-second entry))
           (auto (cl-third entry))
           (default-directory dir))
      (with-current-buffer (shell name)
        (setq emacspeak-comint-autospeak auto)
        (setq emacspeak-wizards--project-shell-directory dir)))))
  (emacspeak-wizards--build-shells-table))

(defun emacspeak-wizards-shell-directory-set ()
  "Define current directory as this shell's project directory."
  (interactive)
  (cl-declare (special emacspeak-wizards--project-shell-directory))
  (setq emacspeak-wizards--project-shell-directory default-directory)
  (emacspeak-auditory-icon 'task-done)
  (message (abbreviate-file-name default-directory)))

;;;###autoload
(defun emacspeak-wizards-shell-directory-reset (&optional prefix)
  "Set current directory to this shell's initial directory if one was
defined.  If not in a shell buffer, switch to our Home shell buffer.
With interactive prefix-arg, change this shell's  project directory to
the current directory."
  (interactive "P")
  (cl-declare (special emacspeak-wizards--project-shell-directory))
  (cond
   ((and prefix (eq major-mode 'shell-mode))
    (setq emacspeak-wizards--project-shell-directory default-directory)
    (emacspeak-auditory-icon 'item)
    (message "%s" (abbreviate-file-name default-directory)))
   ((and (eq major-mode 'shell-mode)
         (process-live-p (get-buffer-process (current-buffer))))
    (emacspeak-auditory-icon 'item)
    (ems--shell-pushd-if-needed
     emacspeak-wizards--project-shell-directory (current-buffer))
    (message (abbreviate-file-name default-directory)))
   (t
    (funcall-interactively #'switch-to-buffer "Home"))))

(defun emacspeak-wizards-shell-re-key (key buffer)
  "Re-key shell-buffer `buffer' to be accessed via key `key'. The old shell
buffer keyed by `key'gets the key of buffer `buffer'."
  (cl-declare (special emacspeak-wizards--shells-table
                       emacspeak-wizards--project-shell-directory))
  (cond
   ((eq buffer (gethash key emacspeak-wizards--shells-table))
    (message "Rekey: Nothing to do"))
   (t
    (setq key ;;; works as a circular list
          (% key (length (hash-table-keys emacspeak-wizards--shells-table))))
    (let ((swap-buffer (gethash key emacspeak-wizards--shells-table))
          (swap-key nil))
      (cl-loop
       for k being the hash-keys of emacspeak-wizards--shells-table do
       (when (eq buffer (gethash k emacspeak-wizards--shells-table))
         (setq swap-key k)))
      (puthash key buffer emacspeak-wizards--shells-table)
      (when swap-key
        (puthash swap-key swap-buffer emacspeak-wizards--shells-table))
      (message "%s is now  on %s" (buffer-name buffer) key)))))

;;;  show commentary:

(defun ems-cleanup-commentary (commentary)
  "Cleanup commentary."
  (save-current-buffer
    (set-buffer (get-buffer-create " *doc-temp*"))
    (erase-buffer)
    (insert commentary)
    (goto-char (point-min))
    (goto-char (point-min))
    (goto-char (point-min))
    (delete-blank-lines)
    (goto-char (point-min))
    (while (re-search-forward "^;+ ?" nil t)
      (replace-match "" nil t))
    (buffer-string)))

;;;  Bullet navigation

(defun emacspeak-wizards-next-bullet ()
  "Navigate to and speak next `bullet'."
  (interactive)
  (search-forward-regexp
   "\\(^ *[0-9]+\\. \\)\\|\\( O \\) *")
  (emacspeak-auditory-icon 'item)
  (emacspeak-speak-line))

(defun emacspeak-wizards-previous-bullet ()
  "Navigate to and speak previous `bullet'."
  (interactive)
  (search-backward-regexp
   "\\(^ *[0-9]+\\. \\)\\|\\(^O\s\\) *")
  (emacspeak-auditory-icon 'item)
  (emacspeak-speak-line))

;;;  Start or switch to term:

;;;  Espeak: MultiLingual Wizard

(defvar emacspeak-wizards-espeak-voices-alist nil
  "Association list of ESpeak voices to voice codes.")

(defun emacspeak-wizards-espeak-build-voice-table ()
  "Build up alist of espeak voices."
  (cl-declare (special emacspeak-wizards-espeak-voices-alist))
  (with-temp-buffer
    (shell-command "espeak-ng  --voices" (current-buffer))
    (goto-char (point-min))
    (forward-line 1)
    (while (not (eobp))
      (let ((fields
             (split-string
              (buffer-substring
               (line-beginning-position) (line-end-position)))))
        (push (cons (cl-fourth fields) (cl-second fields))
              emacspeak-wizards-espeak-voices-alist))
      (forward-line 1))))

(defun emacspeak-wizards-espeak-get-voice-code ()
  "Read and return ESpeak voice code with completion."
  (cl-declare (special emacspeak-wizards-espeak-voices-alist))
  (or emacspeak-wizards-espeak-voices-alist
      (emacspeak-wizards-espeak-build-voice-table))
  (let ((completion-ignore-case t))
    (cdr
     (assoc
      (completing-read "Lang:"
                       emacspeak-wizards-espeak-voices-alist)
      emacspeak-wizards-espeak-voices-alist))))

;;;###autoload
(defun emacspeak-wizards-espeak-string (string)
  "Speak string in lang via ESpeak.
Lang is obtained from property `lang' on string, or via an
interactive prompt."
  (interactive "sString: ")
  (let ((lang (get-text-property 0 'lang string)))
    (unless lang
      (setq lang
            (cond
             ((called-interactively-p 'interactive)
              (emacspeak-wizards-espeak-get-voice-code))
             (t "en"))))
    (shell-command
     (format "espeak -v %s '%s'" lang string))))

;;;###autoload
(defun emacspeak-wizards-espeak-region (start end)
  "Speak region using ESpeak polyglot wizard."
  (interactive "r")
  (save-excursion
    (goto-char start)
    (while (< start end)
      (goto-char
       (next-single-property-change
        start 'lang
        (current-buffer) end))
      (emacspeak-wizards-espeak-string (buffer-substring start (point)))
      (skip-syntax-forward " ")
      (setq start (point)))))

;;;###autoload
(defun emacspeak-wizards-espeak-line ()
  "Speak line using espeak polyglot wizard."
  (interactive)
  (ems-with-messages-silenced
   (emacspeak-wizards-espeak-region
    (line-beginning-position) (line-end-position))))

;;;  Emacs Dev utilities

;;;###autoload
(defun emacspeak-wizards-show-eval-result (form)
  "Pretty-print and view Lisp evaluation results."
  (interactive
   (list
    (read-from-minibuffer
     "Eval: "
     nil read-expression-map t
     'read-expression-history)))
  (cl-declare (special read-expression-map))
  (let ((buffer (get-buffer-create "*emacspeak:Eval*"))
        (print-length nil)
        (eval-expression-print-length nil)
        (print-level nil)
        (eval-expression-print-level nil)
        (result (eval form)))
    (with-current-buffer buffer
      (setq buffer-undo-list t)
      (erase-buffer)
      (condition-case nil
          (cl-prettyprint result)
        (goto-char (point-min))
        (error nil))
      (set-buffer-modified-p nil))
    (pop-to-buffer buffer)
    (emacs-lisp-mode)
    (goto-char (point-min))
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))

(defun emacspeak-wizards-show-memory-used ()
  "Convenience command to view state of memory used in this session so far."
  (interactive)
  (let ((buffer (get-buffer-create "*emacspeak-memory*")))
    (save-current-buffer
      (set-buffer buffer)
      (erase-buffer)
      (insert
       (apply 'format
              "Memory Statistics
 cons cells:\t%d
 floats:\t%d
 vectors:\t%d
 symbols:\t%d
 strings:\t%d
 miscellaneous:\t%d
 integers:\t%d\n"
              (memory-use-counts)))
      (insert "\nInterpretation of these statistics:\n")
      (insert (documentation 'memory-use-counts))
      (goto-char (point-min)))
    (pop-to-buffer buffer)
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))

;;;###autoload
(defun emacspeak-wizards-enumerate-matching-commands (pattern)
  "Return list of commands whose names match pattern."
  (interactive "sFilter Regex: ")
  (let ((result nil))
    (mapatoms
     #'(lambda (s)
         (when (and (commandp s)
                    (string-match pattern (symbol-name s)))
           (push s result))))
    result))

;;;###autoload
(defun emacspeak-wizards-enumerate-uncovered-commands (pattern &optional bound)
  "Enumerate unadvised commands matching pattern.
Optional interactive prefix arg `bound'
filters out commands that dont have an active key-binding."
  (interactive "sFilter Regex:\nP")
  (let ((result nil))
    (mapatoms
     #'(lambda (s)
         (let ((name (symbol-name s)))
           (when
               (and
                (string-match pattern name)
                (commandp s)
                (if bound (where-is-internal s nil nil t) t)
                (not (string-match "^emacspeak" name))
                (not (string-match "^ad-Orig" name))
                (not (ad-find-some-advice s 'any "emacspeak")))
             (push s result)))))
    (sort result
          #'(lambda (a b) (string-lessp (symbol-name a) (symbol-name b))))))

;;;###autoload
(defun emacspeak-wizards-module-enumerate-uncovered-commands (m)
  "Enumerate uncovered commands from module m"
  (interactive (list (read-library-name)))
  (let ((result nil)
        (f
         (format "%sc"
                 (find-library-name m))))
    (mapatoms
     #'(lambda (s)
         (when
             (and
              (commandp s)
              (string= f (symbol-file s))
              (not (ad-find-some-advice s 'any "emacspeak")))
           (push s result))))
    (sort result
          #'(lambda (a b)
              (string-lessp (symbol-name a) (symbol-name b))))))

;;;###autoload
(defun emacspeak-wizards-enumerate-unmapped-faces (&optional pattern)
  "Enumerate unmapped faces matching pattern."
  (interactive "sPattern:")
  (or pattern (setq pattern "."))
  (let ((buffer (get-buffer-create "*Result*"))
        (result
         (delq
          nil
          (mapcar
           #'(lambda (s)
               (let ((name (symbol-name s)))
                 (when
                     (and
                      (string-match pattern name)
                      (null (voice-setup-get-voice-for-face s)))
                   s)))
           (face-list)))))
    (setq result
          (sort result
                #'(lambda (a b)
                    (string-lessp (symbol-name a) (symbol-name b)))))
    (when (called-interactively-p 'interactive)
      (with-help-window buffer
        (cl-prettyprint result)
        (funcall-interactively #'pop-to-buffer buffer)))
    result))

(defun emacspeak-wizards-enumerate-undefined-faces ()
  "utility function to enumerate possibly old, obsolete maps that we have still
mapped to voices."
  (interactive)
  (delq nil
        (mapcar
         #'(lambda (face) (unless (facep face) face))
         (cl-loop for k being the hash-keys of voice-setup-face-voice-table
                  collect k))))

;;;###autoload
(defun emacspeak-wizards-enumerate-matching-faces (pattern)
  "Enumerate  faces matching pattern."
  (interactive "sPattern:")
  (let ((buffer (get-buffer-create "*Result*"))
        (result
         (delq
          nil
          (mapcar
           #'(lambda (s)
               (let ((name (symbol-name s)))
                 (when (string-match pattern name) name)))
           (face-list)))))
    (setq result
          (sort result
                #'(lambda (a b)
                    (string-lessp a b))))
    (when (called-interactively-p 'interactive)
      (with-help-window buffer
        (cl-prettyprint result)
        (funcall-interactively #'pop-to-buffer buffer)))
    result))

;;;  Shell Helper: Path Cleanup

(defun emacspeak-wizards-cleanup-shell-path ()
  "Cleans up duplicates in shell path env variable."
  (interactive)
  (let ((p (cl-delete-duplicates (parse-colon-path (getenv "PATH"))
                                 :test #'string=))
        (result nil))
    (setq result (mapconcat #'identity p ":"))
    (kill-new (format "export PATH=\"%s\"" result))
    (setenv "PATH" result)
    (message (setenv "PATH" result))))

(defun emacspeak-wizards-exec-path-from-shell ()
  "Update exec-path from shell path."
  (interactive)
  (emacspeak-wizards-cleanup-shell-path)
  (let ((dirs (split-string (getenv "PATH") ":"))
        (updated (copy-sequence exec-path)))
    (cl-loop
     for d in dirs do
     (cl-pushnew d updated :test #'string-equal))
    (setq exec-path updated)))

;;;  Run shell command on current file:

;;;###autoload
(defun emacspeak-wizards-shell-command-on-current-file (command)
  "Prompts for and runs shell command on current file."
  (interactive (list (read-shell-command "Command: ")))
  (shell-command (format "%s %s" command (buffer-file-name))))

;;;  Filtered buffer lists:

(defun emacspeak-wizards-view-buffers-filtered-by-predicate (predicate)
  "Display list of buffers filtered by specified predicate."
  (let ((buffer-list
         (cl-loop
          for b in (buffer-list)
          when (funcall predicate b) collect b))
        (buffer (get-buffer-create (format "*: Filtered Buffer Menu"))))
    (cl-assert buffer-list t "No buffers in this mode.")
    (when buffer-list
      (with-current-buffer buffer
        (Buffer-menu-mode)
        (list-buffers--refresh buffer-list)
        (tabulated-list-print))
      buffer)))

(defun emacspeak-wizards-view-buffers-filtered-by-mode (mode)
  "Display list of buffers filtered by specified mode."
  (switch-to-buffer
   (emacspeak-wizards-view-buffers-filtered-by-predicate
    #'(lambda (buffer)
        (with-current-buffer buffer
          (eq major-mode mode)))))
  (rename-buffer (format "Buffers Filtered By  %s" mode) 'unique)
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-speak-line))

;;;###autoload
(defun emacspeak-wizards-view-buffers-filtered-by-this-mode ()
  "Buffer menu filtered by  mode of current-buffer."
  (interactive)
  (emacspeak-wizards-view-buffers-filtered-by-mode major-mode))

;;;###autoload
(defun emacspeak-wizards-view-buffers-filtered-by-m-player-mode ()
  "Buffer menu filtered by  m-player mode."
  (interactive)
  (switch-to-buffer
   (emacspeak-wizards-view-buffers-filtered-by-predicate
    #'(lambda (buffer)
        (with-current-buffer buffer
          (and
           (eq major-mode 'emacspeak-m-player-mode)
           (process-live-p (get-buffer-process buffer)))))))
  (rename-buffer "*Media Player Buffers*" 'unique)
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-speak-line))

;;;###autoload
(defun emacspeak-wizards-eww-buffer-list ()
  "Display list of  EWW buffers."
  (interactive)
  (emacspeak-wizards-view-buffers-filtered-by-mode 'eww-mode))

;;;  TuneIn:

;;;###autoload
(defun emacspeak-wizards-tune-in-radio-browse (&optional category)
  "Browse Tune-In Radio.
Optional interactive prefix arg `category' prompts for a category."
  (interactive "P")
  (emacspeak-url-template-open
   (emacspeak-url-template-get
    (if category "Online RadioTime Categories" "Online RadioTime Browser"))))

;;;###autoload
(defun emacspeak-wizards-tune-in-radio-search ()
  "Search Tune-In Radio."
  (interactive)
  (emacspeak-url-template-open
   (emacspeak-url-template-get "Online RadioTime Search")))

;;;  Sports API:

(defvar emacspeak-wizards--xmlstats-standings-uri
  "https://erikberg.com/%s/standings.json"
  "URI Rest end-point template for standings in a given sport.
At present, handles mlb, nba.")

(defun emacspeak-wizards-xmlstats-standings-uri (sport)
  "Return REST URI end-point,
where `sport' is either mlb or nba."
  (format emacspeak-wizards--xmlstats-standings-uri sport))

(defun emacspeak-wizards--format-mlb-standing (s)
  "Format  MLB standing."
  (let-alist s
    (format
     "* %s %s  are %s in the %s %s.
They are at  %s/%s after %s games for an average of %s.
Current streak is %s; Win/Loss at Home: %s/%s, Away: %s/%s, Conference: %s/%s.
\n"
     .first_name .last_name .ordinal_rank .conference .division
     .won .lost .games_played .win_percentage
     .streak .home_won .home_lost .away_won .away_lost
     .conference_won .conference_lost)))

(defun emacspeak-wizards-mlb-standings (&optional raw)
  "Display MLB standings as of today.
Optional interactive prefix arg shows  unprocessed results."
  (interactive "P")
  (let ((buffer (get-buffer-create "*MLB Standings*"))
        (date (format-time-string "%B %e %Y"))
        (inhibit-read-only t)
        (standings
         (g-json-from-url (emacspeak-wizards-xmlstats-standings-uri "mlb"))))
    (with-current-buffer buffer
      (erase-buffer)
      (special-mode)
      (org-mode)
      (insert (format "* Standings: %s\n\n" date))
      (cond
       (raw
        (cl-loop
         for s across (g-json-get 'standing standings) do
         (cl-loop
          for f in s do
          (insert (format "%s:\t%s\n"
                          (car f) (cdr f))))
         (insert "\n")))
       (t
        (cl-loop
         for s across (g-json-get 'standing standings) do
         (insert (emacspeak-wizards--format-mlb-standing s)))))
      (goto-char (point-min))
      (funcall-interactively #'switch-to-buffer buffer))))

(defun emacspeak-wizards--format-nba-standing (s)
  "Format  NBA standing."
  (let-alist s
    (format
     "%s %s  are %s in the %s %s.
They are at  %s/%s after %s games for an average of %s.
Current streak is %s; Win/Loss at Home: %s/%s, Away: %s/%s, Conference: %s/%s.
\n"
     .first_name .last_name .ordinal_rank .conference .division
     .won .lost .games_played .win_percentage
     .streak .home_won .home_lost .away_won .away_lost
     .conference_won .conference_lost)))

(defun emacspeak-wizards-nba-standings (&optional raw)
  "Display NBA standings as of today.
Optional interactive prefix arg shows  unprocessed results."
  (interactive "P")
  (let ((buffer (get-buffer-create "*NBA Standings*"))
        (date (format-time-string "%B %e %Y"))
        (inhibit-read-only t)
        (standings
         (g-json-from-url (emacspeak-wizards-xmlstats-standings-uri "nba"))))
    (with-current-buffer buffer
      (erase-buffer)
      (special-mode)
      (insert (format "Standings: %s\n\n" date))
      (cond
       (raw
        (cl-loop
         for s across (g-json-get 'standing standings) do
         (cl-loop
          for f in s do
          (insert (format "%s:\t%s\n"
                          (car f) (cdr f))))
         (insert "\n")))
       (t
        (cl-loop
         for s across (g-json-get 'standing standings) do
         (insert (emacspeak-wizards--format-nba-standing s)))))
      (goto-char (point-min))
      (funcall-interactively #'switch-to-buffer buffer))))

;;;  Color at point:
(defun ems--color-diff (c1 c2)
  "Color difference"
  (color-cie-de2000
   (apply #'color-srgb-to-lab (color-name-to-rgb c1))
   (apply #'color-srgb-to-lab (color-name-to-rgb c2))))

;;;###autoload
(defun emacspeak-wizards-set-colors ()
  "Prompt for foreground and background colors."
  (interactive)
  (let ((bg (read-color "Background: "))
        (fg (read-color "Foreground: ")))
    (set-background-color bg)
    (set-foreground-color fg)
    (emacspeak-wizards-color-diff-at-point)))

;;;###autoload
(defun emacspeak-wizards-color-diff-at-point (&optional set)
  "Speak difference between background and foreground color at point.
With interactive prefix arg, set foreground and background color first."
  (interactive "P")
  (when set (call-interactively #'emacspeak-wizards-set-colors))
  (let* ((fg (foreground-color-at-point))
         (bg (background-color-at-point))
         (diff (ems--color-diff fg bg)))
    (message "Color distance is %.2f between %s and %s which is %s" diff
             (ems--color-name fg) (ems--color-name bg)
             (cdr (assq 'background-mode (frame-parameters))))))

(defun ems--color-hex (color)
  "Return Hex value for color."
  (apply #'color-rgb-to-hex (append (color-name-to-rgb color) '(2))))
(defvar ems--color-table (make-hash-table )
  "Table to memoize ntc color names.")

(defun ems--color-name (color)
  "Return a meaningful color-name using name-this-color if available.
Otherwise just return  `color'."
  (interactive "P")
  (cl-declare (special ems--color-table))
  (cond
   ((gethash color ems--color-table) (gethash color ems--color-table))
   ((fboundp 'ntc-name-this-color)
    (let* ((candidate (ntc--get-closest-color color))
           (name (ntc--struct-name (cdr candidate)))
           (shade (ntc--struct-shade (cdr candidate))))
      (cond
       ((string= name shade)
        (puthash color name ems--color-table)
        name)
       (t
        (let ((v (concat
                  (propertize name 'personality voice-bolden)
                  " shaded "
                  (propertize shade 'personality voice-annotate))))
          (puthash color v ems--color-table)
          v)))))
   (t (puthash color color ems--color-table)
      color)))

(defun emacspeak-wizards-frame-colors ()
  "Display frame's foreground/background color setting."
  (interactive)
  (message "%s on %s"
           (ems--color-name
            (frame-parameter (selected-frame) 'foreground-color))
           (ems--color-name
            (frame-parameter (selected-frame) 'background-color))))

(defun emacspeak-wizards--set-color (color)
  "Set color as foreground or background."
  (let ((choice (read-char "f:foreground, b:background")))
    (cl-case choice
      (?b (set-background-color color))
      (?f (set-foreground-color color)))
    (emacspeak-auditory-icon 'select-object)
    (call-interactively #'emacspeak-wizards-frame-colors)))

;;;###autoload
(defun emacspeak-wizards-colors ()
  "Display list of colors and setup a callback to activate color
under point as either the foreground or background color."
  (interactive)
  (list-colors-display nil nil '#'emacspeak-wizards--set-color))

;;;###autoload
(defun emacspeak-wizards-color-at-point ()
  "Echo foreground/background color at point."
  (interactive)
  (require 'name-this-color)
  (let ((weight (faces--attribute-at-point :weight))
        (slant (faces--attribute-at-point :slant))
        (family (faces--attribute-at-point :family)))
    (message "%s %s %s %s on %s"
             (if family family "")
             (if (eq 'normal weight) "" weight)
             (if (eq 'normal slant) "" slant)
             (ems--color-name (foreground-color-at-point))
             (ems--color-name (background-color-at-point)))))

;;;  Color Wheel:
(cl-defstruct ems--color-wheel
  "Color wheel holds RGB balues and step-size."
  red green blue step)

(defun ems--color-wheel-hex (w)
  "Return color value as hex."
  (format "#%02X%02X%02X"
          (ems--color-wheel-red w)
          (ems--color-wheel-green w)
          (ems--color-wheel-blue w)))

(defun ems--color-wheel-name (wheel)
  "Name of color  the wheel is set to currently."
  (ntc-name-this-color
   (format "#%02X%02X%02X"
           (ems--color-wheel-red wheel)
           (ems--color-wheel-green wheel)
           (ems--color-wheel-blue wheel))))

(defun ems--color-wheel-shade (wheel)
  "Shade of color  the wheel is set to currently."
  (ntc-shade-this-color
   (format "#%02X%02X%02X"
           (ems--color-wheel-red wheel)
           (ems--color-wheel-green wheel)
           (ems--color-wheel-blue wheel))))

(defun ems--color-wheel-describe (w fg)
  "Describe the current state of this color wheel."
  (let ((name (ems--color-wheel-name w))
        (hexcol
         (format "#%02X%02X%02X"
                 (ems--color-wheel-red w)
                 (ems--color-wheel-green w)
                 (ems--color-wheel-blue w)))
        (hex
         (format "%02X %02X %02X"
                 (ems--color-wheel-red w)
                 (ems--color-wheel-green w)
                 (ems--color-wheel-blue w)))
        (msg nil))
    (cond
     ((string= fg "red")
      (put-text-property 0 2 'personality voice-bolden hex))
     ((string= fg "green")
      (put-text-property 3 5 'personality voice-bolden hex))
     ((string= fg "blue")
      (put-text-property 6 8 'personality voice-bolden hex)))
    (setq msg (format "%s is a %s shade: %s"
                      name (ems--color-wheel-shade w) hex))
    (setq msg
          (propertize msg 'face `(:foreground ,fg :background ,hexcol)))
    msg))

;;;###autoload
(defun emacspeak-wizards-color-wheel (start)
  "Manipulate a simple color wheel and display the name and shade
  of the resulting color.  Prompts for a color from which to
  start exploration.

Keyboard Commands During Interaction:
Up/Down: Increase/Decrement along current axis using specified step-size.
=: Set value on current axis to number read from minibuffer.
Left/Right: Switch color axis along which to move.
b/f: Quit  wheel after setting background/foreground color to current value.
n: Read color name from minibuffer.
c: Complement  current color.
s: Set stepsize to number read from minibuffer.
q: Quit color wheel, after copying current hex value to kill-ring."
  (interactive (list (color-name-to-rgb (read-color "Start Color: "))))
  (cl-declare (special ems--color-wheel))
  (require 'name-this-color)
  (unless (featurep 'name-this-color)
    (error "This tool requires package name-this-color."))
  (setq start (mapcar #'(lambda (c) (round (* 255 c))) start))
  (let ((continue t)
        (colors '("red" "green" "blue"))
        (color "red")
        (this 0)
        (event nil)
        (w (make-ems--color-wheel
            :red (cl-first start)
            :green (cl-second start)
            :blue (cl-third start)
            :step 8)))
    (while continue
      (setq event (read-event (ems--color-wheel-describe w color)))
      (cond
       ((eq event ?c)
        (emacspeak-auditory-icon 'button)
        (setf (ems--color-wheel-red w) (- 255 (ems--color-wheel-red w)))
        (setf (ems--color-wheel-green w)
              (- 255 (ems--color-wheel-green w)))
        (setf (ems--color-wheel-blue w)
              (- 255 (ems--color-wheel-blue w))))
       ((eq event ?q)
        (setq continue nil)
        (emacspeak-auditory-icon 'close-object)
        (message "Copied color %s %s to kill ring"
                 (ems--color-wheel-hex w)
                 (ems--color-wheel-name w))
        (kill-new (ems--color-wheel-hex w)))
       ((eq event ?f)
        (setq continue nil)
        (emacspeak-auditory-icon 'close-object)
        (set-foreground-color (ems--color-wheel-hex w))
        (message "Setting foreground  color  to %s %s"
                 (ems--color-wheel-hex w)
                 (ems--color-wheel-name w))
        (kill-new (ems--color-wheel-hex w)))
       ((eq event ?b)
        (setq continue nil)
        (emacspeak-auditory-icon 'close-object)
        (set-background-color (ems--color-wheel-hex w))
        (message "Setting background color  to %s %s"
                 (ems--color-wheel-hex w)
                 (ems--color-wheel-name w))
        (kill-new (ems--color-wheel-hex w)))
       ((eq event ?s)
        (setf (ems--color-wheel-step w) (read-number "Step size: ")))
       ((eq event 'left)
        (setq this (% (+ this 2) 3))
        (setq color (elt colors this))
        (dtk-speak (format "%s Axis" color)))
       ((eq event 'right)
        (setq this (% (+ this 1) 3))
        (setq color (elt colors this))
        (dtk-speak (format "%s Axis" color)))
       ((eq event ?n)
        (setq start
              (mapcar #'(lambda (c) (round (* 255 c)))
                      (color-name-to-rgb (read-color "Start Color: "))))
        (setf (ems--color-wheel-red w) (cl-first start))
        (setf (ems--color-wheel-green w) (cl-second start))
        (setf (ems--color-wheel-blue w) (cl-third start)))
       ((eq event ?=)
        (cond
         ((string= color "red")
          (setf (ems--color-wheel-red w) (read-number "Red:"))
          (setf (ems--color-wheel-red w)
                (min 255 (ems--color-wheel-red w))))
         ((string= color "green")
          (setf (ems--color-wheel-green w) (read-number "Green:"))
          (setf (ems--color-wheel-green w)
                (min 255 (ems--color-wheel-green w))))
         ((string= color "blue")
          (setf (ems--color-wheel-blue w) (read-number "Blue:"))
          (setf (ems--color-wheel-blue w)
                (min 255 (ems--color-wheel-blue w))))
         (t (error "Unknown color %s" color))))
       ((eq event 'up)
        (cond
         ((string= color "red")
          (cl-incf (ems--color-wheel-red w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-red w)
                (min 255 (ems--color-wheel-red w))))
         ((string= color "green")
          (cl-incf (ems--color-wheel-green w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-green w)
                (min 255 (ems--color-wheel-green w))))
         ((string= color "blue")
          (cl-incf (ems--color-wheel-blue w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-blue w)
                (min 255 (ems--color-wheel-blue w))))
         (t (error "Unknown color %s" color))))
       ((eq event 'down)
        (cond
         ((string= color "red")
          (cl-decf (ems--color-wheel-red w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-red w)
                (max 0 (ems--color-wheel-red w))))
         ((string= color "green")
          (cl-decf (ems--color-wheel-green w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-green w)
                (max 0 (ems--color-wheel-green w))))
         ((string= color "blue")
          (cl-decf (ems--color-wheel-blue w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-blue w)
                (max 0 (ems--color-wheel-blue w))))
         (t (error "Unknown color %s" color))))
       (t
        (message
         "Left/Right Switches primary, Up/Down increases/decreases."))))))

;;;  Swap Foreground And Background:

;;;###autoload
(defun emacspeak-wizards-swap-fg-and-bg ()
  "Swap foreground and background."
  (interactive)
  (let ((fg (foreground-color-at-point))
        (bg (background-color-at-point)))
    (set-foreground-color bg)
    (set-background-color fg)
    (call-interactively #'emacspeak-wizards-color-diff-at-point)))

;;; Modus Theme And Friends:
;;;###autoload
(defun emacspeak-wizards-show-theme (palette)
  "Display colors in  palette.
Prompts for a color palette variable as used in the modus theme and
  its variants,
and pops to a buffer that describes the colors used in that palette."
  (interactive
   (list
    (intern
     (completing-read
      "Palette: "
      (cl-loop
       for s being the symbols
       when (and (boundp s)
                 (not (functionp s))
                 (string-match ".*palette$" (symbol-name s))) collect
       s)))))                           ; done reading input
  (with-current-buffer (get-buffer-create    "*Colors*") ; produce output
    (let ((inhibit-read-only  t))
      (erase-buffer)
      (insert (format "%s\n" palette))
      (cl-loop
       for p in  (symbol-value palette) 
       when (stringp (cl-second p)) do
       (let ((c (ems--color-name (cl-second p))))
         (insert (format "%s:\t%s\t%s\n" (cl-first p) c (cl-second p))))))
    (setq buffer-read-only t)
    (special-mode))
  (emacspeak-auditory-icon 'open-object)
  (funcall-interactively #'switch-to-buffer "*Colors*")
  (goto-char (point-min))
  (emacspeak-speak-line))
;;;  Utility: Read from a pipe helper:

;; For use from etc/emacs-pipe.pl
;; Above can be used as a printer command in XTerm

(defun emacspeak-wizards-pipe ()
  "convenience function"
  (pop-to-buffer (get-buffer-create " *piped*"))
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-speak-mode-line))

;;;  Customize Saved Settings  By Pattern:

;; Emacs' built-in customize-saved can be slow if the saved
;; customizations are many. This function allows one to clean-up
;; saved settings in smaller groups by specifying a pattern to match.

(defun emacspeak-wizards-customize-saved (pattern)
  "Customize saved options matching `pattern'.  This command enables
updating custom settings for a specific package or group of packages."
  (interactive "sFilter Pattrern: ")
  (let ((found nil))
    (mapatoms #'(lambda (symbol)
                  (and (string-match pattern (symbol-name symbol))
                       (or (get symbol 'saved-value)
                           (get symbol 'saved-variable-comment))
                       (boundp symbol)
                       (push (list symbol 'custom-variable) found))))
    (when (not found) (user-error "No saved user options matching %s"
                                  pattern))
    (ems-with-messages-silenced
     (emacspeak-auditory-icon 'progress)
     (custom-buffer-create
      (custom-sort-items found t nil)
      (format "*Customize %d Saved options Matching %s*" (length
                                                          found) pattern)))
    (emacspeak-auditory-icon 'task-done)
    (emacspeak-speak-mode-line)))

;;;  NOAA Weather API:

(defvar  ems--noaa-grid-endpoint
  "https://api.weather.gov/points/")

(defsubst ems--noaa-get-gridpoint (geo)
  "Return NOAA gridpoint from geo-coordinates."
  (cl-declare (special ems--noaa-grid-endpoint))
  (let-alist geo
    (format "%s%.4f,%.4f" ems--noaa-grid-endpoint .lat .lng)))

;; NOAA: format time
;; NOAA data has a ":" in tz

(defsubst ems--noaa-time (fmt iso)
  "Utility function to correctly format ISO date-time strings from NOAA."
  ;; first strip offending ":" in tz
  (when (and (= (length iso) 25) (char-equal ?: (aref iso 22)))
    (setq iso (concat (substring iso 0 22) "00")))
  (format-time-string fmt (date-to-time iso)))

(defsubst ems--noaa-url (&optional geo)
  "Return NOAA Weather API REST end-point for specified lat/long.
Location is a Lat/Lng pair retrieved from Google Maps API."
  (cl-declare (special gmaps-my-address))
  (cl-assert (or geo gmaps-my-address) nil "Location not specified.")
  (unless geo (setq geo (gmaps-address-geocode gmaps-my-address)))
  (let-alist ;;; return forecast url
      (g-json-from-url (ems--noaa-get-gridpoint geo))
    .properties.forecast))

(defun ems--noaa-get-data (ask)
  "Internal function that gets NOAA data and returns a results buffer."
  (cl-declare (special gmaps-my-address
                       gmaps-location-table))
  (let* ((buffer (get-buffer-create "*NOAA Weather*"))
         (inhibit-read-only t)
         (date nil)
         (fmt "%A  %H:%M %h %d")
         (start (point-min))
         (address
          (if (and ask (= 16 (car ask)))
              (completing-read
               "Address:"
               gmaps-location-table)
            gmaps-my-address))
         (geo (if (and ask (= 16 (car ask)))
                  (gmaps-address-geocode address)
                (gmaps-address-geocode gmaps-my-address)))
         (url (ems--noaa-url geo)))
    (with-current-buffer buffer
      (erase-buffer)
      (org-mode)
      (setq header-line-format (format "NOAA Weather For %s" address))
      ;; produce Daily forecast
      (let-alist (g-json-from-url url)
        (insert
         (format "* Forecast At %s For %s\n\n"
                 (ems--noaa-time fmt .properties.updated)
                 address))
        (cl-loop
         for p across .properties.periods do
         (let-alist p
           (insert
            (format
             "* Forecast For %s: %s\n\n%s\n\n"
             .name .shortForecast .detailedForecast)))
         (fill-region start (point)))
        )
      (let-alist ;;; Now produce hourly forecast
          (g-json-from-url (concat url "/hourly"))
        (insert
         (format "\n* Hourly Forecast:Updated At %s \n"
                 (ems--noaa-time fmt .properties.updated)))
        (cl-loop
         for p across .properties.periods do
         (let-alist p
           (unless (and
                    date
                    (string= date (ems--noaa-time "%x" .startTime)))
             (insert
              (format "** %s\n" (ems--noaa-time "%A %X" .startTime)))
             (setq date (ems--noaa-time "%x" .startTime)))
           (insert
            (format
             "  - %s %s %s:  Wind Speed: %s Wind Direction: %s\n"
             (ems--noaa-time "%R" .startTime)
             .shortForecast
             .temperature .windSpeed .windDirection)))))
      (setq buffer-read-only t)
      (goto-char (point-min)))
    buffer))

;;;###autoload
(defun emacspeak-wizards-noaa-weather (&optional ask)
  "Display weather  using NOAA Weather API.
Address is a string and can include house-number, street name,
city and zip.  Data is retrieved only once, subsequent calls
switch to previously displayed results. Kill that buffer or use
an interactive prefix arg (C-u) to get new data.  Optional second
interactive prefix arg (C-u C-u) asks for location address;
Default is to display weather for `gmaps-my-address'."
  (interactive "P")
  (let ((buffer
         (cond
          (ask (ems--noaa-get-data ask))
          ((get-buffer "*NOAA Weather*") (get-buffer "*NOAA Weather*"))
          (t (ems--noaa-get-data ask)))))
    (switch-to-buffer buffer)
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-line)))

;;;  generate declare-function statements:

(declare-function help--symbol-completion-table
                  "help-fns" (string pred action))

(defun emacspeak-wizards-gen-fn-decl (f &optional ext)
  "Generate declare-function call for function `f'.
Optional interactive prefix arg ext says this comes from an
external package."
  (interactive
   (list
    (read
     (completing-read
      "Function:"
      #'help--symbol-completion-table
      #'functionp))))
  (cl-assert (functionp f) t "Not a valid function")
  (let ((file (symbol-file f 'defun))
        (arglist (help-function-arglist f 'preserve)))
    (cl-assert file t "Function definition not found")
    (setq file (file-name-base file))
    (insert
     (format
      "(declare-function %s \"%s\" %s)\n"
      f
      (if ext (format "ext:%s" file) file)
      arglist))))

;;;  Google Newspaper:
(declare-function eww-display-dom-by-element "emacspeak-eww" (tag))

;;;###autoload
(defun emacspeak-wizards-google-news ()
  "Clean up news.google.com."
  (interactive)
  (cl-declare (special emacspeak-we-xsl-junk emacspeak-we-xsl-filter))
  (add-hook
   'emacspeak-eww-post-process-hook
   #'(lambda nil (eww-display-dom-by-element 'h3)))
  (message "Press l to expand all sections.")
  (emacspeak-we-xslt-pipeline-filter
   `((,emacspeak-we-xsl-filter "//main") ;specs
     (,emacspeak-we-xsl-junk "//menu|//*[contains(@role,\"button\")]"))
   "https://news.google.com"
   'speak))

;;;###autoload
(defun emacspeak-wizards-google-headlines ()
  "Display just the headlines from Google News."
  (interactive)
  (emacspeak-we-xslt-filter "//h3" "https://news.google.com" 'speak))

;;;  Use Threads To Call Command Asynchronously:

;; Experimental: Handle with care.

;;;###autoload
(defun emacspeak-wizards-execute-asynchronously (key)
  "Read key-sequence, then execute its command on a new thread."
  (interactive (list (read-key-sequence "Key Sequence: ")))
  (let ((l (local-key-binding key))
        (g (global-key-binding key))
        (k
         (when-let (map (get-text-property (point) 'keymap))
           (lookup-key map key))))
    (cl-flet
        ((do-it (command)
           (make-thread command)
           (message "Running %s on a new thread." command)))
      (cond
       ((commandp k) (do-it k))
       ((commandp l) (do-it l))
       ((commandp g) (do-it g))
       (t (error "%s is not bound to a command." key))))))

;;;   Free Geo IP:

(defun emacspeak-wizards-free-geo-ip (&optional reverse-geocode)
  "Return list consisting of city and region_name.
Optional interactive prefix arg reverse-geocodes using Google Maps."
  (interactive "P")
  (let-alist
      (g-json-from-url "https://freegeoip.app/json")
    (if reverse-geocode
        (dtk-speak
         (gmaps-reverse-geocode
          `((lat . ,.latitude) (lng . ,.longitude ))))
      (dtk-speak-list (list  .city .region_name)))))

;;;  Open Frame On Remote Emacs:

(defcustom emacspeak-wizards-remote-workstation ""
  "Name of remote workstation."
  :type 'string
  :group 'emacspeak-wizards)

(defun emacspeak-wizards-remote-frame ()
  "Open a frame on a remote Emacs.
Remote workstation is  `emacspeak-wizards-remote-workstation'.
Works best when you already are ssh-impel-ed in and have a talking
  remote Emacs in   a local XTerm."
  (interactive )
  (cl-declare (special emacspeak-wizards-remote-workstation))
  (cl-assert
   (> (length emacspeak-wizards-remote-workstation) 0) t
   "Set emacspeak-wizards-remote-workstation first.")
  (let ((title
         `((name .
                 ,(format
                   "%s:Emacs"
                   (cl-first
                    (split-string
                     emacspeak-wizards-remote-workstation "\\.")))))))
    (with-environment-variables
        (("TERM" "xterm"))
      (start-process
       "REmacs" "*REmacs*" "ssh"
       "-Y" ;;; forward Trusted X11
       emacspeak-wizards-remote-workstation
       "emacsclient" "-c"
       "-a" "''"
       "-F" (shell-quote-argument (prin1-to-string title))))))

;;;  describe-voice at point:
;;;###autoload
(defun emacspeak-wizards-describe-voice(personality)
  "Describe  voice --- analogous to \\[describe-face].
When called interactively, `personality' defaults to first
personality at point. "
  (interactive
   (list
    (let* ((v (dtk-get-style)))
      (setq v
            (if (listp v)
                (mapcar #'symbol-name v)
              (symbol-name v)))
      (when (listp v) (setq v (cl-first v)))
      (read-from-minibuffer
       "Personality: "
       nil nil 'read nil  v))))
  (let ((settings nil)
        (n '(family average-pitch pitch-range stress richness punctuations))
        (values nil))
    (when personality
      (setq settings (intern (format "%s-settings" personality))))
    (cond
     ((symbol-value settings) ;;; globally bound, display it
      (setq values (symbol-value settings))
      (with-help-window (help-buffer)
        (with-current-buffer standard-output
          (insert (format "Personality: %s\n\n" personality ))
          (put-text-property (point-min) (point)
                             'personality personality)
          (cl-loop
           for i from 0 to (1- (length n))do
           (insert (format "%s: %s\n"
                           (elt n i) (elt values i))))))
      (when (called-interactively-p 'interactive)
        (emacspeak-speak-help)))
     (t (message "%s doesn't look like a valid personality." personality)))))

;;;  tex utils:

;;;###autoload
(defun emacspeak-wizards-end-of-word (arg)
  "move to end of word"
  (interactive "P")
  (if arg
      (forward-word arg)
    (forward-word 1))
  (when (called-interactively-p 'interactive)
    (let ((emacspeak-show-point  t))
      (emacspeak-speak-line))))

;;;###autoload
(defun emacspeak-wizards-comma-at-end-of-word ()
  "Move to the end of current word and add a comma."
  (interactive)
  (forward-word 1)
  (insert-char ?,))

;;;###autoload
(defun emacspeak-wizards-lacheck-buffer-file ()
  "Run Lacheck on current buffer."
  (interactive)
  (compile (format "lacheck %s"
                   (buffer-file-name (current-buffer)))))

;;;###autoload
(defun emacspeak-wizards-tex-tie-current-word (n)
  "Tie the next n  words."
  (interactive "P")
  (or n (setq n 1))
  (while
      (> n 0)
    (setq n (- n 1))
    (forward-word 1)
    (delete-horizontal-space)
    (insert-char 126 1))
  (forward-word 1))

;;; Snarf contents of a delimiter

;;;###autoload
(defun emacspeak-wizards-snarf-sexp (&optional delete)
  "Snarf the contents between delimiters at point.
Optional interactive prefix arg deletes it."
  (interactive "P")
  (let ((orig (point))
        (pair nil)
        (pairs
         '((?< ?>)
           (?\[ ?\])
           (?\( ?\))
           (?{ ?})
           (?\" ?\")
           (?' ?')
           (?` ?')
           (?| ?|)
           (?* ?*)
           (?/ ?/)
           (?- ?-)
           (?_ ?_)
           (?~ ?~)))
        (char (char-after))
        (stab nil))
    (setq pair
          (or (assq char pairs)
              (list char (read-char "Close Delimiter: "))))
    (setq stab (copy-syntax-table))
    (with-syntax-table stab
      (cond
       ((= (cl-first pair) (cl-second pair))
        (modify-syntax-entry (cl-first pair) "\"" )
        (modify-syntax-entry (cl-second pair) "\"" ))
       (t
        (modify-syntax-entry (cl-first pair) "(")
        (modify-syntax-entry (cl-second pair) ")")))
      (save-excursion
        (forward-sexp)
        (cond
         (delete
          (kill-region (1+ orig) (1- (point)))
          (emacspeak-auditory-icon 'delete-object))
         (t (kill-ring-save (1+ orig) (1- (point)))
            (emacspeak-auditory-icon 'mark-object)))
        (dtk-speak (car kill-ring))))))

;;; Brightness Alert:

;; Watch for screen brightness changes and let user know if screen
;; comes on:

(defvar emacspeak-brightness-alert-delay 30
  "Number of seconds of idle time
before brightness is checked.")

(defvar emacspeak-brightness-timer nil
  "Idle timer that runs our brightness alert.")

(defcustom emacspeak-brightness-autoblack nil
  "Set to T to automatically turn display black."
  :type 'boolean
  :group 'emacspeak-wizards)

(defun emacspeak-brightness-alert ()
  "Check  brightness, alert and autoblack if set."
  (cl-declare (special emacspeak-brightness-autoblack))
  (with-local-quit
    (unless (zerop (light-get))
      (emacspeak-auditory-icon 'alert-user)
      (when emacspeak-brightness-autoblack (light-black))
      (message "Brightness %s." (light-get)))))

;;;###autoload
(defun emacspeak-brightness-alert-toggle ()
  "Toggle brightness alert."
  (interactive)
  (cl-declare (special emacspeak-brightness-timer))
  (cond
   ((null emacspeak-brightness-timer)
    (setq emacspeak-brightness-timer
          (run-with-timer
           emacspeak-brightness-alert-delay
           emacspeak-brightness-alert-delay
           'emacspeak-brightness-alert)))
   (t (cancel-timer emacspeak-brightness-timer)
      (setq emacspeak-brightness-timer nil)))
  (when (called-interactively-p 'interactive)
    (message "turned %s brightness alert"
             (if emacspeak-brightness-timer "on" "off"))
    (emacspeak-auditory-icon
     (if emacspeak-brightness-timer 'on 'off))))

;;;###autoload
(defun emacspeak-brightness-autoblack-toggle ()
  "Toggle brightness autoblack."
  (interactive)
  (cl-declare (special emacspeak-brightness-autoblack))
  (setq emacspeak-brightness-autoblack (not emacspeak-brightness-autoblack))
  (when (called-interactively-p 'interactive)
    (message "Turned %s autoblack"
             (if emacspeak-brightness-autoblack ' "on" "off"))
    (emacspeak-auditory-icon
     (if emacspeak-brightness-autoblack 'on 'off))))

;;;  Content Locator:

;; Content locate wizard:
;; Like  m-player-locate-media but for documents (tex,html, org, pdf

(defvar emacspeak-wizards-content-extensions
  (eval-when-compile
    (let
        ((ext
          '("tex" "org" "html" "pdf")))
      (concat
       "\\."
       (regexp-opt (append ext (mapcar #'upcase ext)) 'parens)
       "$")))
  "Content extensions.")

(defun emacspeak-wizards-locate-content (pattern)
  "Locate content matching  pattern.  The results can be
 opened by \\[emacspeak-dired-open-this-file] locally bound to C-RET ."
  (interactive "sSearch Pattern: ")
  (cl-declare  (special emacspeak-wizards-content-extensions
                        locate-command locate-make-command-line))
  (let ((inhibit-read-only t)
        (locate-make-command-line
         #'(lambda (s) (list locate-command "-i" "--regexp" s))))
    (locate-with-filter
     (mapconcat #'identity
                (split-string pattern)
                "[ '/\"_.,-]")
     emacspeak-wizards-content-extensions)
    (goto-char (point-min))
    (emacspeak-auditory-icon 'open-object)
    (rename-buffer (format "Content  matching %s" pattern))
    (emacspeak-speak-mode-line)))

;;; BC Sounds:
;;;###autoload
(defun emacspeak-wizards-bbc-sounds ()
  "Search BBC Sounds.
Result page is filtered down to two sections, Shows and Episodes.

Press [RET] on links in the Show section to open that show page.
The page for that show contains playable links for Episodes.

Press `y' on Episode links to play them with MPV."
  (interactive)
  (emacspeak-url-template-open (emacspeak-url-template-get "BBC Sounds")))

(defun emacspeak-wizards-bbc-iplayer ()
  "Browse BBC Schedule from get_iplayer radio cache.
Bug: First run fails to bind keys.   Works on subsequent runs."
  (interactive)
  (funcall-interactively
   #'emacspeak-forms-find-file
   (expand-file-name "forms/get-iplayer.el" emacspeak-etc-directory)))


;;; Portfolio:

;;;###autoload
(defun emacspeak-wizards-quotes ()
  "View stock quotes"
  (interactive )
  (emacspeak-url-template-open (emacspeak-url-template-get "CNBC Quotes")))

;;;  end of file

;; byte-compile-warnings: (noruntime )

