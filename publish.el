; STUFF FOR #+BEGIN_SRC BLOCKS
;; Set the package installation directory so that packages aren't stored in the
; ;; ~/.emacs.d/elpa path.
(require 'package)
(setq package-user-dir (expand-file-name "./.packages"))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))

;; Initialize the package system
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; Install dependencies
(package-install 'htmlize)

(require 'ox-publish)

; see https://pank.eu/blog/blog-setup.html

;; Customize the HTML output
(setq org-html-validation-link nil             ;; Don't show validation link
;      org-html-head-include-scripts nil       ;; js scripts to include
;      org-html-head-include-default-style nil ;; don't use default css stylesheet
;      org-html-head "<link rel=\"stylesheet\" href=\"https://cdn.simplecss.org/simple.min.css\" />")
       org-html-html5-fancy t                  ;; ...
       org-html-preamble t
       org-html-divs '((preamble "header" "top") (content "main" "content") (postamble "footer" "postamble"))
       org-html-head (concat
                      "<title>andersch.dev</title>"
                      "<link rel=\"icon\" type=\"image/x-icon\" href=\"favicon.ico\">"                               ; favicon
                      "<style>" (with-temp-buffer (insert-file-contents "style.css") (buffer-string)) "</style>")    ; css stylesheet
       org-html-preamble-format `(("en" ,(with-temp-buffer (insert-file-contents "header.html") (buffer-string)))))

(defun my-format-rss-feed (title list)
  (let* ((list-entries   (cdr list))
         (orig-buffer (current-buffer))
         (latest-article "")
         (buf-str "")
         (latest-project ""))
    (mapcar (lambda (elem)
              (when (string= (car elem) "articles")
                (setq latest-article (car (car (cdr (car (cdr elem))))))
                (switch-to-buffer (find-file-noselect "articles.org" nil nil nil))
                ; NOTE WORKAROUND for invalid-search-bound bug
                (setq buf-str (buffer-string))
                (with-temp-file "articles.org"
                  (insert
                    (replace-regexp-in-string "@@start:articles@@.*\\(\n.*\\)*@@end:articles@@"
                      (format "@@start:articles@@\n%s\n@@end:articles@@" (org-list-to-org (car (cdr elem))))
                      buf-str nil t)))
                (kill-buffer "articles.org"))
              (when (string= (car elem) "projects")
                (setq latest-project (car (car (cdr (car (cdr elem))))))
                (switch-to-buffer (find-file-noselect "projects.org" nil nil nil))
                ; NOTE WORKAROUND for invalid-search-bound bug
                (setq buf-str (buffer-string))
                (with-temp-file "projects.org"
                  (insert
                    (replace-regexp-in-string "@@start:projects@@.*\\(\n.*\\)*@@end:projects@@"
                      (format "@@start:projects@@\n%s\n@@end:projects@@" (org-list-to-org (car (cdr elem))))
                      buf-str nil t)))
                (kill-buffer "projects.org")))
            list-entries)

    ; NOTE WORKAROUND for invalid-search-bound bug
    (switch-to-buffer (find-file-noselect "index.org" nil nil nil))
    (setq buf-str (buffer-string))
    (with-temp-file "index.org"
      (setq buf-str (replace-regexp-in-string "@@start:article@@.*\\(\n.*\\)*@@end:article@@"
          (format "@@start:article@@%s@@end:article@@" latest-article) buf-str nil t))
      (insert
        (replace-regexp-in-string "@@start:project@@.*\\(\n.*\\)*@@end:project@@"
          (format "@@start:project@@%s@@end:project@@" latest-project) buf-str nil t)))
    (switch-to-buffer orig-buffer))
    (kill-buffer "index.org")

  (concat "#+TITLE: " title "\n\n" (org-list-to-org list))) ; NOTE this writes to sitemap.org

(defun my-format-rss-feed-entry (entry style project)
  ;; RSS entry
  (when (and (string-match-p "articles/" entry) (not (string= entry "articles/")))
    (save-excursion
      (switch-to-buffer (find-file-noselect entry))
      (cd "..") ; go up from "articles/"
      (write-region
        (format "<item>\n<title>%s</title>\n<link>%s</link>\n<guid>%s</guid>\n<description>%s</description>\n<pubDate>%s</pubDate>\n</item>\n"
              (org-publish-find-title entry project)
              (concat "http://andersch.dev/" (string-replace ".org" ".html" entry))
              (concat "http://andersch.dev/" (string-replace ".org" ".html" entry))
              (alist-get "DESCRIPTION" (org-collect-keywords '("DESCRIPTION") '("DESCRIPTION")) nil nil 'string=)
              (format-time-string "%a, %d %b %Y %H:%M:%S %z" (seconds-to-time (org-publish-find-date entry project))))
        nil "feed.rss" 'append)))

  ;; sitemap entry
  (cond ((not (directory-name-p entry))
         (format "[[file:%s][%s]]"
             entry
             (org-publish-find-title entry project)))
        ((eq style 'tree)
          ;; Return only last subdir.
          (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

(setq org-publish-project-alist
      (list
       (list "andersch.dev"
             :recursive            t
             :base-directory       "./"
             :publishing-directory "../publish/"
             :publishing-function  'org-html-publish-to-html ;; may be a list of functions
           ; :preparation-function                           ;; called before publishing
           ; :completion-function                            ;; called after
           ; :base-extension                                 ;; extension of source files
             :exclude "sitemap.org"                          ;; regex of files to exclude NOTE excluding dirs seems to not work
           ; :include                                        ;; list of files to include

             :auto-sitemap         t                         ;; https://orgmode.org/manual/Site-map.html
             :sitemap-filename     "sitemap.org"             ;; ...
           ; :sitemap-title
             :sitemap-style        'tree                     ;; list or tree
             :sitemap-sort-files   'anti-chronologically
             :sitemap-function     'my-format-rss-feed
             :sitemap-format-entry 'my-format-rss-feed-entry

           ; :makeindex t                                    ;; https://orgmode.org/manual/Generating-an-index.html

             :with-title           nil                       ;; we include our own header
             :with-author          nil
             :with-creator         nil                       ;; don't include emacs and org versions in footer
             :with-toc             nil                       ;; no table of contents
             :section-numbers      nil                       ;; no section numbers for headings
             :time-stamp-file      nil)                      ;; don't include "Created: <timestamp>" in footer
       (list "attachments"
             :recursive            t
             :base-directory "./"
             :base-extension "png\\|jpg\\|rss"
             :publishing-directory "../publish/"
             :publishing-function 'org-publish-attachment
     )))

(with-temp-file "feed.rss" ; hardcoded rss header, check with  https://validator.w3.org/feed/
  (insert
   (let* ((website-title "andersch.dev")
          (homepage      "https://andersch.dev")
          (rss-filepath  "/feed.rss"))
   (concat "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
           "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\">\n"
           "<channel>\n"
           (format "<title>%s</title>\n" website-title)
           "<!-- <lastBuildDate>Wed, 15 Dec 2021 00:00:00 +0000</lastBuildDate> -->\n" ; TODO insert todays date
           (format "<atom:link href=\"%s%s\" rel=\"self\" type=\"application/rss+xml\"/>\n" homepage rss-filepath)
           (format "<link>%s/index.html</link>\n" homepage)
           "<description>Stuff on programming</description>\n"
           "<language>en-us</language>\n"))))


; NOTE caching causes problems with updating titles etc., so we reset the cache before publishing
(setq org-publish-use-timestamps-flag nil)
(setq org-publish-timestamp-directory "./.org-timestamps/")
(org-publish-remove-all-timestamps)
; NOTE these resets seem unnessecary
;(org-element-cache-reset)
;(org-refile-cache-clear)
;(org-reset-file-cache)
;(org-publish-reset-cache)

(org-publish "andersch.dev" t) ;; generate rss feed, expand @@..@@ markers, export html files, copy image files
(write-region "</channel>\n</rss>" nil "feed.rss" 'append) ;; hardcoded rss ending
(org-publish "attachments")  ;; copy image files

(message "Build complete")
