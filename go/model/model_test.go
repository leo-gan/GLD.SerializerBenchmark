package model

import "testing"

func TestObjectGraphTopology(t *testing.T) {
	g := makeObjectGraph()
	if g.Root != 0 {
		t.Fatalf("root=%d", g.Root)
	}
	if len(g.Nodes) != 3 {
		t.Fatalf("nodes=%d", len(g.Nodes))
	}
	root, c1, c2 := g.Nodes[0], g.Nodes[1], g.Nodes[2]
	if root.Name != "Root" || root.Parent != GRAPH_NULL || root.Related != GRAPH_NULL {
		t.Fatalf("root node: %+v", root)
	}
	if len(root.Children) != 2 || root.Children[0] != 1 || root.Children[1] != 2 {
		t.Fatalf("root children: %v", root.Children)
	}
	if c1.Name != "Child1" || c1.Parent != 0 || c1.Related != 2 {
		t.Fatalf("child1: %+v", c1)
	}
	if c2.Name != "Child2" || c2.Parent != 0 || c2.Related != 1 {
		t.Fatalf("child2: %+v", c2)
	}
	if !ObjectGraphFidelity(g, g) {
		t.Fatal("self-fidelity failed")
	}
}

func TestAllFixturesIncludeObjectGraph(t *testing.T) {
	fxs := AllFixtures(42)
	found := false
	for _, fx := range fxs {
		if fx.Name == "ObjectGraph" {
			found = true
			if _, ok := fx.Value.(ObjectGraph); !ok {
				t.Fatalf("ObjectGraph value type %T", fx.Value)
			}
		}
	}
	if !found {
		t.Fatal("ObjectGraph missing from AllFixtures")
	}
}

func TestNewEmptyPtrObjectGraph(t *testing.T) {
	ptr := NewEmptyPtr(ObjectGraph{})
	if _, ok := ptr.(*ObjectGraph); !ok {
		t.Fatalf("got %T", ptr)
	}
	if d, ok := Deref(ptr).(ObjectGraph); !ok {
		t.Fatalf("deref %T", Deref(ptr))
	} else if d.Root != 0 {
		t.Fatalf("empty root %d", d.Root)
	}
}
