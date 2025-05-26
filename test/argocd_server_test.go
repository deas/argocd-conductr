package test

import (
	"context"
	"fmt"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Argo Server Deployment", func() {
	var clientset *kubernetes.Clientset

	BeforeEach(func() {
		// Load kubeconfig and create clientset
		kubeconfig := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
			clientcmd.NewDefaultClientConfigLoadingRules(),
			&clientcmd.ConfigOverrides{},
		)
		config, err := kubeconfig.ClientConfig()
		Expect(err).NotTo(HaveOccurred())

		clientset, err = kubernetes.NewForConfig(config)
		Expect(err).NotTo(HaveOccurred())
	})

	It("should have the desired number of replicas", func() {
		deploymentName := "argocd-server"
		namespace := "argocd"

		// Get the deployment
		deployment, err := clientset.AppsV1().Deployments(namespace).Get(context.TODO(), deploymentName, metav1.GetOptions{})
		Expect(err).NotTo(HaveOccurred())

		// Check if the actual replicas match the desired replicas
		desiredReplicas := *deployment.Spec.Replicas
		actualReplicas := deployment.Status.ReadyReplicas

		Expect(actualReplicas).To(Equal(desiredReplicas), fmt.Sprintf("Expected %d replicas, but found %d", desiredReplicas, actualReplicas))
	})
})
