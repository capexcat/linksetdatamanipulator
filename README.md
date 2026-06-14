# LSDm: LINKSET DATA MANIPULATOR - OFFICIAL DOCUMENTATION by CapeXCat

## What is this?

LSDm (Linkset Data Manipulator) is a dynamic memory allocation library written in LSL for Second Life. It utilizes the Linkset Data (LSD) system to simulate a persistent, virtual memory heap. It maintains a linked list of freed memory blocks to efficiently recycle keys, acting much like `malloc` and `free` in C.

## Why has it been created?

LSL scripts have severe memory limitations. While Linden Lab introduced Linkset Data to allow for a larger data store shared across the linkset, LSL lacks native complex data structures like arrays or pointers. LSDm bridges this gap, allowing scripters to build complex, scalable data structures without hitting script memory limits.

## What features does it provide?

* **Dynamic Garbage Collection:** Automatically reuses freed memory addresses (via `g_free_head`) to prevent key-space bloat.
* **Type Safety:** Encodes data types (`s:`, `i:`, `f:`, `p:`) into the stored strings to ensure accurate data retrieval.
* **Pointer Mathematics:** Simulates offset calculations for array iteration.
* **Advanced Memory Operations:** Includes safe implementations of `MemCopy` (with overlapping block protection), `MemSwap`, `MemSet`, `MemCmp`, and `MemReverse`.
* **Dynamic Resizing:** Supports reallocating arrays while preserving old data.

## Functions Available & Detailed Usage

### CORE ALLOCATION & DEALLOCATION

* `AllocateRaw(string type_prefix, string data)`
    * **Description:** The core allocator. Pulls a free address or generates a new one, formatting the LSD key as `mem_addr_X`.
    * **Parameters:** `type_prefix` (e.g., "s", "i") and `data` (the stringified value).
    * **Returns:** A string pointer (e.g., `"mem_addr_0"`) or `"ERROR_OUT_OF_MEMORY"`
    * **Example:** `string ptr = AllocateRaw("s", "Hello");`

* `FreeMemory(string pointer_key)`
    * **Description:** Deletes the data at the pointer and adds the address to the free list for recycling.
    * **Parameters:** `pointer_key` (the pointer string).
    * **Returns:** `integer` (TRUE if successful, FALSE if invalid)
    * **Example:** `FreeMemory(ptr);`

### TYPE-SAFE HELPERS

* `AllocateString(string value)` | `AllocateInt(integer value)` | `AllocateFloat(float value)` | `AllocatePointer(string target_ptr)`
    * **Description:** Wrappers for `AllocateRaw` that enforce type prefixes.
    * **Returns:** String pointer to the allocated memory.
    * **Example:** `string myInt = AllocateInt(42);`

* `ReadRaw(string pointer_key)` / `WriteRaw(string pointer_key, string typed_value)`
    * **Description:** Bypasses type-stripping to read/write the exact string stored in LSD (e.g., "i:42").
    * **Returns:** String value or `"ERROR_NULL_POINTER"` on read; TRUE/FALSE on write.

* `ReadString(string ptr)` / `ReadInt(string ptr)` / `ReadFloat(string ptr)` / `ReadDoublePointer(string ptr)`
    * **Description:** Reads the raw value, strips the type prefix, and casts it to the requested LSL type. Includes fail-safes (e.g., reading an integer via `ReadFloat` safely casts it).
    * **Returns:** The correctly typed value (or `0`/`0.0`/`"ERROR_NULL_POINTER"` if invalid).
    * **Example:** `integer val = ReadInt(myInt);`

* `WriteString(string ptr, string val)` / `WriteInt(string ptr, integer val)` / `WriteFloat(string ptr, float val)` / `WritePointer(string ptr, string target)`
    * **Description:** Writes a new value to an existing pointer while preserving its type prefix.
    * **Returns:** `integer` (TRUE on success).
    * **Example:** `WriteInt(myInt, 99);`

### ARRAYS & POINTER MATH

* `EvaluateAddressOffset(string base_pointer, integer index)`
    * **Description:** Calculates the pointer key for an index within an array.
    * **Parameters:** `base_pointer` (e.g., `"mem_addr_0"`), `index` (the offset).
    * **Returns:** A formatted string pointer (e.g., `"mem_addr_0_5"`).

* `AllocateArray(integer size, string type_prefix, string default_value)`
    * **Description:** Allocates a contiguous block of memory elements. If an allocation fails mid-way, it deletes the partial array safely.
    * **Returns:** The base pointer string, or an error string.
    * **Example:** `string arr = AllocateArray(10, "i", "0");`

* `FreeArray(string base_pointer, integer size)`
    * **Description:** Iterates through an array and frees all sub-elements and the base pointer.
    * **Returns:** `integer` (TRUE/FALSE).

* `ReallocArray(string old_base, integer old_size, integer new_size, string type_prefix, string default_value)`
    * **Description:** Changes the size of an array. Copies existing data to the new array and frees the old one.
    * **Returns:** New base pointer string.

### ADVANCED MEMORY OPERATIONS

* `MemCopy(string dest_base, string src_base, integer elements)`
    * **Description:** Copies data from a source array to a destination. Intelligently detects overlap and reverses copy direction if necessary to prevent data corruption.
* `MemSwap(string pointer_a, string pointer_b, integer elements)`
    * **Description:** Swaps the values of two memory blocks element by element.
* `MemSet(string dest_base, string type_prefix, string value, integer elements)`
    * **Description:** Overwrites an entire array block with a specific value.
* `MemCmp(string pointer_a, string pointer_b, integer elements)`
    * **Description:** Compares two memory blocks. Returns TRUE if identical, FALSE otherwise.
* `MemReverse(string base_pointer, integer elements)`
    * **Description:** Reverses the order of elements in an array in-place using `MemSwap`.

## Why is it bug-free?

LSDm is highly defensive. It guards against memory leaks during failed allocations by looping backward to clean up partial arrays. Its reading functions safely handle null pointers, and it intelligently parses differing number types (int vs float) if requested incorrectly. Finally, the `MemCopy` overlap detection guarantees that shifting data arrays forward will not overwrite data before it is copied.

## Where can I use it?

Ideal for complex game engines, localized database processing, advanced sorting algorithms, and HUD configurations where variables frequently change size, get created, and are destroyed over the script's lifetime.
