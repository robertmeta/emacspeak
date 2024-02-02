;;; emacspeak-muggles.el --- Convenience Hydras -*- lexical-binding: t; -*-
;; $Author: tv.raman.tv $
;; Description:  Speech-enable MUGGLES An Emacs Interface to muggles
;; Keywords: Emacspeak,  Audio Desktop muggles
;;;   LCD Archive entry:

;; LCD Archive Entry:
;; emacspeak| T. V. Raman |tv.raman.tv@gmail.com
;; A speech interface to Emacs |
;; Location https://github.com/tvraman/emacspeak
;;

;;;   Copyright:
;; Copyright (C) 1995 -- 2007, 2011, T. V. Raman
;; Copyright (c) 1994, 1995 by Digital Equipment Corporation.
;; All Rights Reserved.
;;
;; This file is not part of GNU Emacs, but the same permissions apply.
;;
;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNMUGGLES FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; Commentary:

;; MUGGLES ==  Emacspeak spells for power-users.

;; This module implements no new functionality --- contrast with
;; emacspeak-wizards.  Instead, it uses package hydra to provide
;; convenience key-bindings that access existing Emacspeak
;; functionality.
;; You need to install package Hydra first:
;; @samp{M-x package-install  hydra}.

;; Note that on newer versions of Emacs, loading this module will
;; attempt to automatically install package hydra if it is not found.
;; @subsection Using Hydras
;; See the high-level documentation for the Hydra package by executing
;; @kbd {C-h C-j } hydra @kbd{RET}.
;; The documentation in this section uses the same terminology as
;; shown in the hydra package documentation.

;; @subsection Implemented Muggles

;; @itemize
;; @item Brightness: @kbd{print} Control display brightness using light.
;; @item Navigate: @kbd{s-n} Navigate with ease.
;; @item  org-mode tables: @kbd{C-c t} Table UI for org-mode tables.
;; @item hideshow: C-, h Provide HideShow bindings.
;; @item toggle-option:  @kbd{C-c o} Single binding for toggling options.
;; @item Repeatable-Yank: @kbd{C-y} Smart yank
;; @item undo-only/undo-redo: @kbd{C-/ } Undo-only on @kbd{/} and
;; undo-redo on @kbd{\}
;; @item emacspeak-maths @kbd{s-SPC} Speak and browse math.
;; @end itemize

;; Emacspeak automatically speaks Hydra hints when displayed.
;; To silence all Hydra hints, set hydra-is-helpful to nil.  To
;; temporarily silence speaking of Hydra hints, Muggles can bind
;; command @code{emacspeak-hydra-toggle-talkative}.  As an
;; example, Muggle @samp{ViewMode} binds @code{s} to this command.

;;; Code:

;;;   Required modules

(eval-when-compile (require 'cl-lib)
                   (setq byte-compile-warnings '(not docstrings)))
(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'hydra "hydra" 'no-error)
(require 'emacspeak-hydra)
(require 'org)
(require 'hideshow)
(require 'ido)
(require 'emacspeak-maths nil 'no-error)
(require 'emacspeak-outline)
(require 'smartparens "smartparens" 'no-error)
(require 'browse-kill-ring "browse-kill-ring" 'no-error)
(require 'xbacklight)
(require 'view)
(require 'emacspeak-m-player)

;; Don't burp if absent during compilation.
(declare-function org-table-previous-row "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-current-element
                  "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-coordinates "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-both-headers-and-element
                  "emacspeak-org" nil)
(declare-function
 emacspeak-org-table-speak-row-header-and-element "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-column-header-and-element
                  "emacspeak-org" nil)

;;;  Brightness:

(global-set-key
 (kbd "<print>")
 (defhydra
  emacspeak-muggles-brightness
  (:body-pre
   (progn
     (when hydra-is-helpful (emacspeak-hydra-toggle-talkative))
     (emacspeak-hydra-body-pre "brightness"))
   :hint nil
   :pre emacspeak-hydra-pre
   :post emacspeak-hydra-post)
  "Brightness "
  ("?" (emacspeak-hydra-self-help "emacspeak-muggles-brightness") "Help")
  ("b" emacspeak-brightness-alert-toggle "Alert" )
  ("s" light-set "set")
  ("g" light-get "Get")
  ("t" emacspeak-hydra-toggle-talkative)
  ("<print>" light-black "black" :color blue)
  ("s-." light-black "black" :color blue)
  ("." light-black "black" :color blue)
  ("0" light-black "black" :color blue)
  ("1" light-white  "white" :color blue)
  ("d" light-decrement "dimmer")
  ("i" light-increment "brighter")
  ("SPC" light-increment "brighter")))

(global-set-key (kbd "s-.") 'emacspeak-muggles-brightness/body)

;;;  Org-Mode Table Navigation:
(with-eval-after-load "org"
  (define-key
   org-mode-map (kbd "C-c t")
   (defhydra emacspeak-muggles-org-table
             (:body-pre
              (progn
                (emacspeak-hydra-body-pre "Org Table UI")
                (when hydra-is-helpful (emacspeak-hydra-toggle-talkative)))
              :pre emacspeak-hydra-pre :post emacspeak-hydra-post)
             "Org Table UI"
             ("?"(emacspeak-hydra-self-help "emacspeak-muggles-org-table"))
             ("j" org-table-next-row)
             ("k" org-table-previous-row)
             ("h" org-table-previous-field)
             ("l" org-table-next-field)
             ("SPC"emacspeak-org-table-speak-current-element)
             ("."emacspeak-org-table-speak-coordinates)
             ("b"emacspeak-org-table-speak-both-headers-and-element)
             ("r"emacspeak-org-table-speak-row-header-and-element)
             ("c"emacspeak-org-table-speak-column-header-and-element))))

;;;  HideShow:

(global-set-key
 (kbd "C-, h")
 (defhydra  emacspeak-muggles-hideshow
            (
             :body-pre
             (progn
               (emacspeak-hydra-body-pre  "Hide Show")
               (hs-minor-mode 1))
             :pre emacspeak-hydra-pre :post emacspeak-hydra-post :color blue)
            "Hideshow"
            ("?" (emacspeak-hydra-self-help "emacspeak-muggles-hideshow"))
            ("h" hs-hide-block)
            ("s" hs-show-block)
            ("H" hs-hide-all)
            ("S" hs-show-all)
            ("a"  hs-show-all)
            ("l" hs-hide-level)
            ("i" hs-hide-initial-comment-block)))

;;;  Option Toggle

;; Cloned from hydra-examples.el and modified to tase.
;;; Helper:

(defun emacspeak-muggles-lispy-or-sp ()
  "Toggle between lispy and smartparens."
  (interactive)
  (cl-declare (special lispy-mode smartparens-mode))
  (lispy-mode 'toggle)
  (smartparens-mode 'toggle)
  (emacspeak-auditory-icon 'button)
  (message "Now using %s"
           (cond
            (lispy-mode "Lispy")
            (smartparens-mode "Smart Parens")
            (t "neither lispy or sp"))))

(global-set-key
 (kbd "C-c o")
 (defhydra
  emacspeak-muggles-toggle-option
  (
   :color blue
   :body-pre (emacspeak-hydra-body-pre "Toggle Option ")
   :pre
   (progn
     (emacspeak-hydra-pre)
     (unless hydra-is-helpful (emacspeak-hydra-toggle-talkative)))
   :post emacspeak-hydra-post)
  "
_a_ abbrev-mode: %`abbrev-mode
_d_ debug-on-error:    %`debug-on-error
_g_ debug-on-quit:    %`debug-on-quit
_h_ hydra-is-helpful    %`hydra-is-helpful
_p_ emacspeak-muggles-lispy-or-sp:
"
  ("?" (emacspeak-hydra-self-help "emacspeak-muggles-toggle-option"))
  ("a" (call-interactively #'abbrev-mode))
  ("d" (call-interactively #'toggle-debug-on-error))
  ("g"  (call-interactively #'toggle-debug-on-quit))
  ("h" (setq hydra-is-helpful (not hydra-is-helpful)))
  ("p" emacspeak-muggles-lispy-or-sp)
  ("q" nil "quit")))

;;;  Navigate:

;; Inspired by  Hydra wiki:
;; But bound to s-n --- instead of C-n

(global-set-key
 (kbd "s-n")
 (defhydra emacspeak-muggles-navigate
           (:body-pre
            (progn
              (emacspeak-hydra-body-pre "Navigator")
              (emacspeak-hydra-toggle-talkative)
              (condition-case nil (call-interactively #'next-line) (error nil)))
            :hint nil
            :pre emacspeak-hydra-pre :post emacspeak-hydra-post)
           "Navigator"
           ("?" (emacspeak-hydra-self-help "emacspeak-muggles-navigate"))
           ("s" emacspeak-hydra-toggle-talkative "quiet")
           ("n" next-line "next ")
           ("p" previous-line "previous ")
           ("f" forward-char)
           ("b" backward-char)
           ("a" beginning-of-line)
           ("e" move-end-of-line)
           ("j" next-line)
           ("k" previous-line)
           ("v" scroll-up-command)
           ;; Converting M-v to V here by analogy.
           ("V" scroll-down-command)
           ("l" recenter-top-bottom)
           ("<" beginning-of-buffer)
           (">" end-of-buffer)))

;;;  Repeatable Yank

;; Repeatable yank(-pop) command, with an option to switch to a list view using
;; browse-kill-ring.

;; Helper: IDo Search for kill ring

(defun emacspeak-muggles-ido-yank ()
  "Pick what to yank using ido completion."
  (interactive)
  (when (eq last-command 'yank)
    (delete-region (region-beginning) (region-end)))
  (let ((orig (point)))
    (insert
     (ido-completing-read
      "Yank what? " (mapcar 'substring-no-properties kill-ring)))
    (when (called-interactively-p 'interactive)
      (emacspeak-auditory-icon 'yank-object)
      (emacspeak-speak-region orig (point)))))

(global-set-key (kbd "M-C-y") 'emacspeak-muggles-ido-yank)

(defhydra
 emacspeak-muggles-yank-pop
 (:body-pre (emacspeak-hydra-body-pre "Yank")
            :pre
            (progn
              (when hydra-is-helpful (emacspeak-hydra-toggle-talkative))
              (emacspeak-hydra-pre))
            :post emacspeak-hydra-post)
 "Yank"
 ("?" (emacspeak-hydra-self-help "emacspeak-muggles-yank-pop"))
 ("C-y" yank nil)
 ("M-y" yank-pop nil)
 ("y" (funcall-interactively #'yank-pop 1) "next")
 ("Y" (funcall-interactively #'yank-pop -1) "prev")
 ("i" emacspeak-muggles-ido-yank "IDo Yank" :color blue)
 ("s" emacspeak-muggles-ido-yank "IDo Yank" :color blue)
 ("l" browse-kill-ring "list" :color blue))

(global-set-key (kbd "M-y") #'emacspeak-muggles-yank-pop/yank-pop)
(global-set-key (kbd "C-y") #'emacspeak-muggles-yank-pop/yank)

;;;  Repeatable Undo

;; Repeatable undo-only and undo-redo
(global-set-key
 (kbd "C-/")
 (defhydra
  emacspeak-muggles-undo-only/undo-redo
  (:body-pre (emacspeak-hydra-body-pre "Undo Smartly")
             :pre
             (progn
               (when hydra-is-helpful (emacspeak-hydra-toggle-talkative))
               (emacspeak-hydra-pre))
             :post emacspeak-hydra-post)
  "Undo"
  ("?" (emacspeak-hydra-self-help "emacspeak-muggles-undo-only/undo-redo"))
  ("/" undo-only nil)
  ("\\" undo-redo nil)))

;;;   Speak And Browse Math

(global-set-key
 (kbd "s-SPC")
 (defhydra emacspeak-muggles-maths-navigator
           (:body-pre
            (progn
              (when hydra-is-helpful (emacspeak-hydra-toggle-talkative))
              (emacspeak-hydra-body-pre "Spoken Math"))
            :pre emacspeak-hydra-pre
            :post emacspeak-hydra-post)
           "Spoken Math"
           ("o" emacspeak-maths-switch-to-output :color blue)
           ("RET" emacspeak-maths-enter-guess)
           ("SPC" emacspeak-maths-enter "enter")
           ("a" emacspeak-maths-speak-alt "Alt Text")
           ("d" emacspeak-maths-depth "Depth")
           ("r" emacspeak-maths-root "Root")
           ("<up>" emacspeak-maths-up "Up")
           ("<down>" emacspeak-maths-down"down")
           ("<left>" emacspeak-maths-left "left")
           ("<right>" emacspeak-maths-right "right")))

(provide 'emacspeak-muggles)
;;;  end of file

;; byte-compile-warnings: (docstring  noruntime)
