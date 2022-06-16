#ifndef BVH_GLSL
#define BVH_GLSL

/*
My thoughts when planning to implement a BVH:

Fixed depth BVH: We cram everything into a single texture

How I would do this in C/++:

struct BVH_Leaf{
	// Number of triangles in this leaf
	uint32_t TriangleCount;
	// Since we are indexing the triangle buffer, we need to have a pointer to a list of indices to the indices of the vertex buffer
	uint32_t* Contents;
	// Traversal looks like this:
	// for each Triangle count:
	//    GetTriangle(IndexBuffer[Contents[Index]]).Intersect([...]);
};

struct BVH_Node {
	// Bounding box of this node
	AABB BoundingBox;
	// We either contain children nodes for traversal or we contian the leaf nodes
	// We know which one it is based on BVH depth, which can be a uniform variable
	// But beware that it does not exceed the fixed size stack
	union {
		BVH_Node* Children[2];
		BVH_Leaf* Leaf;
	};
}

Adaptation to the GPU:
First of all, replace every pointer with an index to a texture or something
This nicely allows the union in BVH_Node to not have any wasted memory
We also can support up to 4 billion or something triangles now if we use uints,
although I wish 24 bit integers were a thing since 4 billion is way too much

I might use a depth like 8 or 11 since that should nicely work in my case

I also would put everything into a texture since that allows me to use "unions" 
since I can directly reinterpret data read instead of doing conversions and stuff

I'll use a buffer texture due to higher size limits

So let's look at what an AABB requires:
1. 3 floats (12 bytes) for extent[0]
2. 3 floats (12 bytes) for extent[1]
24 bytes so far, that's not divisble by the 16 byte alignment or cache stuff whatever you call it

Then the union requires:
1. 4 bytes for the first pointer
2. 4 bytes for the second point
The union in total requires 8 bytes

If we add that to our previous 24 bytes, we get 32 bytes
24 + 8 = 32

Now we divide by 16
32 / 16 = 2

We're quite lucky since we can neatly pack this into 2 vec4s

Now you maybe asking: "But how do we reinterpret floats as int (or ints as float) when we read from the texture"?
Answer: floatBitsToUint https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/floatBitsToInt.xhtml 

Now comes the mpore difficult part: packing the leaf contents
Now that I tink about it, it's not a good idea to put everything into a single texture,
since the variable amount of uints for the leaf contents will not work well fdor the
vec4 16 byte alignment and it will generally become a nightmare

So instead I might have 2 textures:

uniform samplerBuffer BVH_Nodes;
uniform samplerBuffer BVH_LeafContents;

BVH_Nodes is what we have been dealing with: storing all the BVH nodes;
BVH_LeafContents is about storing the uint data about triangle indices to indices.
We can do a single uint alignment and make our lives easier

We can also put these into a single buffer and access different portions by using
glTexBufferRange to access the BVH and leaf contents seperately

My idea for memory layout of buffer

[----------|---------]
BVH nodes    leaf contents

BVH nodes (layer = depth):
[--------------------------------------------------]
layer 0   layer 1   layer 2   layer 3   layer 4 layer N

Leaf contents (leaf)
[-------------------------------------------------]
leaf 0 indeices   leaf 1 indices   leaf 2 indices

Depth is probably controlled by a uniform variable
Although this may cause a stack overflow (at which time
you should go to stackoverflow and I'm not sorry for the
bad joke), it allows for a lot more felxibility when 
constructing and traversing the BVH

Also I might try to read a paper about a short stack BVH or even a stackeless BVH traversal method
*/

/*
We need to sperate the nodes into two structs since GLSL
is bad and weird and does not allow unions

I also include a generic node class and inherit from it the good old C way of
having it as a member of a derived struct
*/

/*
Traversal

First, we get the root node
For the root node, we process the children and get the intersection bounds for t
We can cull nodes based on t then
We also sort nodes by their own t
Nodes that are processed later get pushed onto a stack
A stack index is incremented
Stack size is 664
Then we iterate through the node's children

Pusedoscode:

Node root  = get root node ();

Node current node = root;



do
	ray bounds = intersect current node

	if did not intersect current node
		if stack is not empty
			go to next node on stack
		else
			exit traversal loop

	if current node is leaf
		for each triangle in leaf
			intersect triangle
	else
		intersect child[0]
		intersect child[1]

		if hit at least one child
			traverse intersected child
		if hit both children
			sort children by t
			push further child on stack
		else
			go to next node on stack

for each child in current node

Alternative (we also store info about intersection info)

if did not intersect root node
	continue

push root node on stack

while true
	if stack is empty
		break

	current node = get next node on stack

	if current node is farther than current intersection distance
		continue

	if current node is leaf
		for each triangle in leaf
			current intersection distance = intersect triangle
			intersection distance = max(intersection distance, current intersection)
	else
		intersect both children

		if did hit both children
			sort children by distance t
			push furthest child onto stack first
			push closest  child onto stack second
		else if hit single child
			push child onto stack
		else
			continue

Suggested by mad man

push root node on stack

while true
	if stack is empty
		break

	current node = get next node on stack

	intersect node

	if node aabb intersection entry > exit
		continue

	if current node is leaf
		for each triangle in leaf
			current intersection distance = intersect triangle
			intersection distance = max(intersection distance, current intersection)
	else
		intersect children
		sort children by distance
		push both children onto the stack

*/

/*
Some things I further learned from mad man:
Alia et al uses negative indices to encode leaves


*/

/*
Current traversal algorithm, based on a combanation of madman's implementation and my implementation

Stack[0] = GetRootNode();
StackIndex = 0;

while(true) {
	// Stack is empty
	if(StackIndex == -1) {
		break;
	}

	// Pop the next node from the stack
	Node CurrentNode = Stack[StackIndex--];

	AABBIntersection = Intersect(CurrentNode.BoundingBox, Ray)



}




*/

/*

next node = root node

while true

	intersect both children of next node

	intersection 1 = hit child 1 and is not occluded
	intersection 2 = hit child 2 and is not occluded

	sort children by hit distance

	if intersection 1 and child 1 is leaf
		ray triangle intersect with child 1 contents
		process child 1 = false

	if intersection 2 and child 2 is leaf
		ray triangle intersect with child 2 contents
		process child 2 = false

	if intersection 1
		if intersection 2
			push child 2 onto stack
		next node = child 1
	else if intersection 2
		next node = child 2
	else
		if stack is empty
			break
		else
			next node = get next node from stack

*/

#include "../geometry/AABB.glsl"

// Leaf of a BVH
struct BVHLeaf {
	// Beginning of pointer
	int Index;
	// Size of array (also could be end of array,if I was using iterators like in C++)
	int IndexCount;
};

// Generic node wit ha bounding box
struct BVHNode {
	AABB BoundingBox;
};

// Node to represent a generic node

struct BVHNodeGeneric {
	BVHNode Node;

	int Data[2];
};

// Node to represent a node that refrences other nodes
struct BVHNodeRecursive {
	BVHNode Node;

	int ChildrenNodes[2];
};

// Node to represent a node that contains (or more correctly, is) a leaf
struct BVHNodeLeaf {
	BVHNode Node;

	BVHLeaf Leaf;
};

/*
BVH stack

We store depth as well just in case with don't hit other nodes
*/




#endif

/*
I want the closer valid intersection to be first
*/

/*



if (!ChildrenIntersectionSuccess[0]) {
	if (!ChildrenIntersectionSuccess[1]) {
		// We missed the contents of this node; we need to go to the next one on the stack
		TRAVERSE_STACK();
	}
}
*/