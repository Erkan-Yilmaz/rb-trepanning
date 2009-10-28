;; -------------------------------------------------------------------
;; Dependencies.
;;
(eval-when-compile
  (require 'cl))

(defun rbdbgr-directory ()
  "The directory of this file, or nil."
  (let ((file-name (or load-file-name
                       (symbol-file 'rbdbgr-directory))))
    (if file-name
        (file-name-directory file-name)
      nil)))

(setq load-path (cons nil (cons (rbdbgr-directory) load-path)))
(require 'rbdbg-track)
(require 'gud)  ; FIXME: GUD is BAD! It is too far broken to be fixed.
(require 'rbdbgr-regexp)
(require 'rbdbg-scriptbuf-var)
(setq load-path (cddr load-path))


;; FIXME: move to a more common location. rbdbg-core ? 
(defun rbdbgr-strip-command-arg (args two-args opt-two-args)
  "return ARGS with the first argument, an 'option'
removed. 

However if that option argument may take another argument, remove
that as well. TWO-ARGS is list of options (strings without the
leading dash) that take a mandatory additional
argument. OPT-TWO-ARGS is a list of options might take two
arguments. The rule for an optional argument we use: if the next
parameter starts with a dash ('-'), it is not part of the
preceeding parameter when that parameter is optional.

NOTE: we don't check whether the first arguments of ARGS is an
option by testing to see if it starts say with a dash. So on
return the first argument is always removed.
"
  (let ((arg (car args))
	(d-two-args (mapcar (lambda(x) (concat "-" x)) two-args))
	(d-opt-two-args (mapcar (lambda(x) (concat "-" x)) opt-two-args))
	(remaining (cdr args)))
    (cond 
     ((member arg d-two-args)
      (if remaining (cdr remaining)
	  (progn 
	    (message "Expecting an argument after %s. Continuing anyway."
		     arg)
	    remaining)))
     ((member arg d-opt-two-args)
      (if (and remaining (not (string-match "^-" (car remaining))))
	  (cdr remaining)
	remaining))
     (t remaining))))

(defun rbdbgr-get-script-name (orig-args)
  "Parse command line ARGS for the annotate level and name of script to debug.

ARGS should contain a tokenized list of the command line to run.

We return the script name to be debugged and whether option the
annotate option (either '--annotate' or '-A') was set."
  ;; Parse the following:
  ;;
  ;;  [ruby ruby-options] rbdbgr rbdbgr-options script-name script-options
  (let ((args orig-args)
	(script-name nil)
	(annotate-p nil)
	(ruby-opt-two-args '("0" "C" "e" "E" "F" "i"))
	;; Ruby doesn't have mandatory 2-arg options in our sense,
	;; since the two args can be run together, e.g. "-C/tmp" or "-C /tmp"
	;; 
	(ruby-two-args '())
	(debugger-name)
	;; One dash is added automatically to the below, so
	;; h is really -h and -host is really --host.
	(rbdbgr-two-args '("h" "-host" "p" "-port"
			   "I" "-include" "-r" "-require"))
	(rbdbgr-opt-two-args '()))
    (if (not (and args))
	;; Got nothing: return '(nil, nil)
	'(script-name annotate-p)
      ;; else
      ;; Strip off optional "ruby" or "ruby182" etc.
      (when (string-match "^ruby[-0-9]*$"
			  (file-name-sans-extension
			   (file-name-nondirectory (car args))))
	(pop args) ; remove whatever "ruby" thing found.

	;; Strip off Ruby-specific options
	(while (and args
		    (string-match "^-" (car args)))
	  (setq args (rbdbgr-strip-command-arg 
		      args ruby-two-args ruby-opt-two-args))))

      ;; Remove "rbdbgr" from "rbdbgr --rbdbgr-options script
      ;; --script-options"
      (setq debugger-name (file-name-sans-extension
			   (file-name-nondirectory (car args))))
      (unless (string-match "^rbdbgr$" debugger-name)
	(message 
	 "Expecting debugger name to be rbdbgr; got `%s'. Stripping anyway."
	 debugger-name))
      (pop args)
      ;; Skip to the first non-option argument.
      (while (and args (not script-name))
	(let ((arg (car args)))
	  (cond
	   ;; Annotation or emacs option with level number.
	   ((or (member arg '("--annotate" "-A"))
		(equal arg "--emacs"))
	    (setq annotate-p t)
	    (pop args))
	   ;; Combined annotation and level option.
	   ((string-match "^--annotate=[0-9]" arg)
	    (pop args)
	    (setq annotate-p t))
	   ;; Options with arguments.
	   ((string-match "^-" arg)
	    (setq args (rbdbgr-strip-command-arg 
			args rbdbgr-two-args rbdbgr-opt-two-args)))
	   ;; Anything else must be the script to debug.
	   (t (setq script-name arg)))))
      (list script-name annotate-p))))

(defun rbdbgr-file-ruby-mode? (filename)
  "Return true if FILENAME is a buffer we are visiting a buffer
that is in ruby-mode"
  (let ((buffer (and filename (find-buffer-visiting filename)))
	(cur-buff (current-buffer))
	(match-pos))
    (if buffer 
	(progn 
	  (save-excursion
	    (switch-to-buffer buffer 't)
	    (setq match-pos (string-match "^ruby-" (format "%s" major-mode))))
	  (switch-to-buffer cur-buff)
	  (and match-pos (= 0 match-pos)))
      nil)))


(defun rbdbgr-suggest-ruby-file ()
    "Suggest a Ruby file to debug. First priority is given to the
current buffer. If the major mode is Ruby-mode, then we are
done. If the major mode is not Ruby, we'll use priority 2 and we
keep going.  Then we will try files in the default-directory. Of
those that we are visiting we will see if the major mode is Ruby,
the first one we find we will return.  Failing this, we see if the
file is executable and has a .rb suffix. These have priority 8.
Failing that, we'll go for just having a .rb suffix. These have
priority 7. And other executable files have priority 6.  Within a
given priority, we use the first one we find."
    (let* ((file)
	   (file-list (directory-files default-directory))
	   (priority 2)
	   (result (buffer-file-name)))
      (if (not (rbdbgr-file-ruby-mode? result))
	  (while (and (setq file (car-safe file-list)) (< priority 8))
	    (setq file-list (cdr file-list))
	    (if (rbdbgr-file-ruby-mode? file)
		(progn 
		  (setq result file)
		  (setq priority 
			(if (file-executable-p file)
			    (setq priority 8)
			  (setq priority 7)))))
	    ;; The file isn't in a Ruby-mode buffer,
	    ;; Check for an executable file with a .rb extension.
	    (if (and file (file-executable-p file)
		     (not (file-directory-p file)))
		(if (and (string-match "\.rb$" file))
		    (if (< priority 6)
			(progn
			  (setq result file)
			  (setq priority 6))))
	      ;; Found some sort of executable file.
	      (if (< priority 5)
		  (progn
		    (setq result file)
		    (setq priority 5))))))
      result))

(defun rbdbgr-query-cmdline ()
  "Prompt for a rbdbgr debugger command invocation to run.
Analogous to `gud-query-cmdline'"
  ;; FIXME: keep a list of recent invocations.
  (let ((debugger (rbdbg-scriptbuf-var-name rbdbgr-scriptvar))
	(cmd-name (rbdbg-scriptbuf-var-cmd rbdbgr-scriptvar)))
    (read-from-minibuffer
     (format "Run %s (like this): " debugger)
     (concat cmd-name " " (or (rbdbgr-suggest-ruby-file))))))

(defun rbdbgr-goto-line-for-type (type pt)
  "Display the location mentioned in line described by PT. TYPE is used
to get a regular-expresion pattern matching information."
  (interactive "d")
  (save-excursion
    (goto-char pt)
    (lexical-let* ((proc-buff (current-buffer))
		   (proc-window (selected-window))
		   (curr-proc (get-buffer-process proc-buff))
		   (start (line-beginning-position))
		   (end (line-end-position))
		   (tb (gethash type rbdbgr-dbgr-pat-hash))
		   ;; FIXME check that tb is not null and abort if it is.
		   (loc (rbdbg-track-loc (buffer-substring start end)
					 (rbdbg-dbgr-loc-pat-regexp tb)
					 (rbdbg-dbgr-loc-pat-file-group tb)
					 (rbdbg-dbgr-loc-pat-line-group tb)
					 )))
    (if loc (rbdbg-track-loc-action loc proc-buff proc-window)))))

(defun rbdbgr-goto-traceback-line (pt)
  "Display the location mentioned by the Ruby traceback line
described by PT."
  (interactive "d")
  (rbdbgr-goto-line-for-type "traceback" pt))

(defun rbdbgr-goto-dollarbang-traceback-line (pt)
  "Display the location mentioned by the Ruby $! traceback line
described by PT."
  (interactive "d")
  (rbdbgr-goto-line-for-type "dollar-bang" pt))

;; Perform initializations common to all debuggers.
;; The first arg is the specified command line,
;; which starts with the program to debug.
;; The other three args specify the values to use
;; for local variables in the debugger buffer.
;;; (defun rbdbgr-common-init (rbdbgr-buffer-name rbdbgr-cmd-buffer target-name
;;; 					      program args
;;; 					      marker-filter
;;; 					      &optional find-file)
;;;   "Perform initializations common to all debuggers.

;;; RBDBGR-BUFFER-NAME is the specified command line, which starts
;;; with the program to debug. PROGRAM, ARGS and MARKER-FILTER
;;; specify the values to use for local variables in the debugger
;;; buffer."
;;;   (if rbdbgr-cmd-buffer
;;;       (progn
;;; 	(pop-to-buffer rbdbgr-cmd-buffer)
;;; 	(when (and rbdbgr-cmd-buffer (get-buffer-process rbdbgr-cmd-buffer))
;;; 	  (error "This program is already being debugged"))
;;; 	(apply 'make-comint rbdbgr-buffer-name program nil args)
;;; 	(or (bolp) (newline)))
;;;     (pop-to-buffer (setq rbdbgr-cmd-buffer
;;; 			 (apply 'make-comint rbdbgr-buffer-name program nil
;;; 				args))))
  
;;;   ;; Since comint clobbered the mode, we don't set it until now.
;;;   (gud-mode)
;;;   (set (make-local-variable 'gud-target-name) target-name)
;;;   (set (make-local-variable 'gud-marker-filter) marker-filter)
;;;   (set (make-local-variable 'gud-debugger) 'rbdbgr)
;;;   (set (make-local-variable 'gud-last-frame) nil)
;;;   (set (make-local-variable 'gud-last-last-frame) nil)

;;;   (let ((buffer-process (get-buffer-process (current-buffer))))
;;;     (if buffer-process
;;; 	(progn 
;;; 	  (set-process-filter buffer-process 'gud-filter)
;;; 	  (set-process-sentinel buffer-process 'gud-sentinel))))
;;;   (gud-set-buffer))

;; ;;;###autoload
;; (defun rbdbgr (command-line)
;;   "Invoke the rbdbgr Ruby debugger and start the Emacs user interface.

;; String COMMAND-LINE specifies how to run rbdbgr."
;;   (interactive
;;    (let ((init (buffer-file-name)))
;;      (setq init (and init
;;                      (file-name-nondirectory init)))
;;      (list (gud-query-cmdline 'rbdbgr init))))
;;   ;; (rbdbgr-set-window-configuration-state 'debugger t)
;;   ;; Parse the command line and pick out the script name and whether
;;   ;; --annotate has been set.
;;   (let* ((words (with-no-warnings
;; 		  (split-string-and-unquote command-line)))
;; 	 (script-name-annotate-p (rbdbgr-get-script-name
;; 				  (gud-rbdbgr-massage-args "1" words)))
;; 	 (target-name (file-name-nondirectory (car script-name-annotate-p)))
;; 	 (annotate-p (cadr script-name-annotate-p))
;; 	 (cmd-buffer-name (format "rbdbgr-cmd-%s" target-name))
;; 	 (rbdbgr-cmd-buffer-name (format "*%s*" cmd-buffer-name))
;; 	 (rbdbgr-cmd-buffer (get-buffer rbdbgr-cmd-buffer-name))
;; 	 (program (car words))
;; 	 (args (cdr words))
;; 	 (gud-chdir-before-run nil))
    
;;     ;; `gud-rbdbgr-massage-args' needs whole `command-line'.
;;     ;; command-line is refered through dynamic scope.
;;     (rbdbgr-common-init cmd-buffer-name rbdbgr-cmd-buffer target-name
;; 			program args
;; 			'gud-rbdbgr-marker-filter
;; 			'gud-rbdbgr-find-file)
;;     (setq comint-process-echoes t)
    
;;     ;; (setq rbdbgr-inferior-status "running")
    
;;     (rbdbgr-command-initialization)
    
;;     ;; Setup exit callback so that the original frame configuration
;;     ;; can be restored.
;;     ;; (let ((process (get-buffer-process rbdbg-buffer)))
;;     ;;   (when process
;;     ;;     (unless (equal rbdbgr-line-width 120)
;;     ;; 	    (gud-call (format "set width %d" rbdbgr-line-width)))
;;     ;;     (set-process-sentinel process
;;     ;;                           'rbdbgr-process-sentinel)))
    
    
;;     ;; Add the buffer-displaying commands to the Gud buffer,
;;     ;; FIXME: combine with code in rbdbgr-track.el; make common
;;     ;; command buffer mode map.
;;     (let ((prefix-map (make-sparse-keymap)))
;;       (define-key (current-local-map) gud-key-prefix prefix-map)
;;       (define-key prefix-map "t" 'rbdbgr-goto-traceback-line)
;;       (define-key prefix-map "!" 'rbdbgr-goto-dollarbang-traceback-line)
;;       (rbdbgr-populate-secondary-buffer-map-plain prefix-map))
    
;;     (rbdbgr-populate-common-keys (current-local-map))
;;     (rbdbgr-populate-debugger-menu (current-local-map))
    
;;     ;; (setq comint-prompt-regexp (concat "^" rbdbgr-input-prompt-regexp))
;;     ;; (setq paragraph-start comint-prompt-regexp)
    
;;     ;; (setcdr (assq 'rbdbgr-debugger-support-minor-mode minor-mode-map-alist)
;;     ;;         rbdbgr-debugger-support-minor-mode-map-when-active)
;;     ;; (when rbdbgr-many-windows
;;     ;;   (rbdbgr-setup-windows-initially))
    
;;     (run-hooks 'rbdbgr-mode-hook)))


(defun rbdbgr-reset ()
  "Rbdbgr cleanup - remove debugger's internal buffers (frame,
breakpoints, etc.)."
  (interactive)
  ;; (rbdbgr-breakpoint-remove-all-icons)
  (dolist (buffer (buffer-list))
    (when (string-match "\\*rbdbgr-[a-z]+\\*" (buffer-name buffer))
      (let ((w (get-buffer-window buffer)))
        (when w
          (delete-window w)))
      (kill-buffer buffer))))

;; (defun rbdbgr-reset-keymaps()
;;   "This unbinds the special debugger keys of the source buffers."
;;   (interactive)
;;   (setcdr (assq 'rbdbgr-debugger-support-minor-mode minor-mode-map-alist)
;; 	  rbdbgr-debugger-support-minor-mode-map-when-deactive))


(defun rbdbgr-customize ()
  "Use `customize' to edit the settings of the `rbdbgr' debugger."
  (interactive)
  (customize-group 'rbdbgr))


;; -------------------------------------------------------------------
;; The end.
;;

(provide 'rbdbgr-core)

;;; Local variables:
;;; eval:(put 'rbdbgr-debug-enter 'lisp-indent-hook 1)
;;; End:

;;; rbdbgr-core.el ends here
