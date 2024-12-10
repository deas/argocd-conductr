(ns split-k8s-manifests
  (:require [clojure.java.io :as io]
            [clj-yaml.core :as yaml]))

(defn load-yaml-stream [file-path]
  "Loads a YAML stream into a sequence of resources."
  (with-open [rdr (io/reader file-path)]
    (doall (yaml/parse-stream rdr))))

(defn save-yaml [file-path data]
  "Writes YAML data to a file."
  (with-open [wrtr (io/writer file-path)]
    (.write wrtr (yaml/generate-string data))))

(defn process-resources [resources output-dir]
  "Processes the resources and writes them into categorized files."
  (let [crds (filter #(= "CustomResourceDefinition" (:kind %)) resources)
        rbac-kinds #{"Role" "ClusterRole" "RoleBinding" "ClusterRoleBinding"}
        rbac (filter #(contains? rbac-kinds (:kind %)) resources)
        others (remove #(or (= "CustomResourceDefinition" (:kind %))
                            (contains? rbac-kinds (:kind %))) resources)]

    ;; Save CRDs
    (when (seq crds)
      (save-yaml (str output-dir "/crds.yaml") crds))

    ;; Save RBAC resources
    (when (seq rbac)
      (save-yaml (str output-dir "/rbac.yaml") rbac))

    ;; Save other resources individually
    (doseq [resource others]
      (let [kind (:kind resource)
            name (get-in resource [:metadata :name])
            file-path (str output-dir "/" kind "-" name ".yaml")]
        (save-yaml file-path resource)))))

(defn -main [& args]
  (let [input-file (first args)
        output-dir (or (second args) ".")
        resources (load-yaml-stream input-file)]
    (process-resources resources output-dir)))

