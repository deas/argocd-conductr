#!/usr/bin/env bb
(ns split-k8s-manifests
  (:require [clojure.java.io :as io]
            [clojure.string :as str]
            [clj-yaml.core :as yaml]))

(defn load-yaml-stream [rdr]
  "Loads a YAML stream into a sequence of resources."
  ;; (with-open [rdr (io/reader file-path)]
  (doall (yaml/parse-stream rdr {:load-all true})))

(defn save-yaml [file-path data]
  "Writes YAML data to a file."
  ;; (println file-path " " (sequential? data))
  (with-open [wrtr (io/writer file-path)]
    (.write wrtr
           (if (sequential? data)
             (->> data
                 (map #(yaml/generate-string % :dumper-options {:flow-style :block}))
                 (str/join "---\n"))
              (yaml/generate-string data :dumper-options {:flow-style :block})))))

(defn process-resources [resources suffix]
  "Processes the resources and writes them into categorized files."
  (let [crds-dir "./crds"
        templates-dir "./templates"
        crds (filter #(= "CustomResourceDefinition" (:kind %)) resources)
        rbac-kinds #{"Role" "ClusterRole" "RoleBinding" "ClusterRoleBinding"}
        rbac (filter #(contains? rbac-kinds (:kind %)) resources)
        others (remove #(or (= "CustomResourceDefinition" (:kind %))
                            (contains? rbac-kinds (:kind %))) resources)]

    ;; Save CRDs
    (when (seq crds)
      (save-yaml (str crds-dir "/crds" suffix ".yaml") crds))

    ;; Save RBAC resources
    (when (seq rbac)
      (save-yaml (str templates-dir "/rbac" suffix ".yaml") rbac))

    ;; Save other resources individually
    (doseq [resource others]
      (let [kind (:kind resource)
            name (get-in resource [:metadata :name])
            file-path (str templates-dir "/" kind "-" name ".yaml")]
        (save-yaml file-path resource)))))

(defn -main [& args]
  (let [;; input-file (first args)
        suffix (or (first args) "")
        resources (->> (load-yaml-stream *in* #_(io/reader input-file))
                       (filter some?))] ;; Not quite sure where those nile come from in cert-manager.yaml
    (process-resources resources suffix)))

(when (= *file* (System/getProperty "babashka.file"))
  (apply -main *command-line-args*))
