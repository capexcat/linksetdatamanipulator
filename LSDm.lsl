// ==============================================================================
// LSDm: LINKSET DATA MANIPULATOR by CapeXCat
// ==============================================================================
integer g_next_address = 0;
integer g_active_allocations = 0;
integer g_free_head = -1;
// ==============================================================================
// CORE ALLOCATION & DEALLOCATION
// ==============================================================================
string AllocateRaw(string type_prefix, string data)
{
    integer addr;
    if (g_free_head != -1)
    {
        addr = g_free_head;
        string free_key = "sys_free_" + (string)addr;
        g_free_head = (integer)llLinksetDataRead(free_key);
        llLinksetDataDelete(free_key);
    }
    else
    {
        addr = g_next_address;
        g_next_address++;
    }

    string ptr = "mem_addr_" + (string)addr;
    if (!llLinksetDataWrite(ptr, type_prefix + ":" + data)) return "ERROR_OUT_OF_MEMORY";

    g_active_allocations++;
    return ptr;
}
integer FreeMemory(string pointer_key)
{
    if (llSubStringIndex(pointer_key, "mem_addr_") != 0) return FALSE;
    if (llLinksetDataRead(pointer_key) == "") return FALSE;

    llLinksetDataDelete(pointer_key);
    g_active_allocations--;

    list parts = llParseString2List(pointer_key, ["_"], []);
    if (llGetListLength(parts) == 3)
    {
        integer addr = (integer)llList2String(parts, 2);
        llLinksetDataWrite("sys_free_" + (string)addr, (string)g_free_head);
        g_free_head = addr;
    }
    return TRUE;
}
// ==============================================================================
// TYPE-SAFE READ/WRITE/ALLOCATE HELPERS
// ==============================================================================
string AllocateString(string value) { return AllocateRaw("s", value); }
string AllocateInt(integer value) { return AllocateRaw("i", (string)value); }
string AllocateFloat(float value) { return AllocateRaw("f", (string)value); }
string AllocatePointer(string target_ptr) { return AllocateRaw("p", target_ptr); }

string ReadRaw(string pointer_key)
{
    string raw = llLinksetDataRead(pointer_key);
    if (raw == "") return "ERROR_NULL_POINTER";
    return raw;
}
integer WriteRaw(string pointer_key, string typed_value)
{
    if (llLinksetDataRead(pointer_key) == "") return FALSE;
    return llLinksetDataWrite(pointer_key, typed_value);
}
string ReadString(string pointer_key)
{
    string raw = ReadRaw(pointer_key);
    if (raw == "ERROR_NULL_POINTER") return raw;
    return llDeleteSubString(raw, 0, 1);
}
integer ReadInt(string pointer_key)
{
    string raw = ReadRaw(pointer_key);
    if (raw == "ERROR_NULL_POINTER") return 0;
    string type = llGetSubString(raw, 0, 0);
    string val = llDeleteSubString(raw, 0, 1);

    if (type == "i") return (integer)val;
    if (type == "f") return (integer)((float)val);
    return 0;
}
float ReadFloat(string pointer_key)
{
    string raw = ReadRaw(pointer_key);
    if (raw == "ERROR_NULL_POINTER") return 0.0;
    string type = llGetSubString(raw, 0, 0);
    string val = llDeleteSubString(raw, 0, 1);

    if (type == "f") return (float)val;
    if (type == "i") return (float)((integer)val);
    return 0.0;
}
string ReadDoublePointer(string double_pointer_key)
{
    string raw = ReadRaw(double_pointer_key);
    if (raw == "ERROR_NULL_POINTER") return "ERROR_INVALID_DOUBLE_POINTER";

    string type = llGetSubString(raw, 0, 0);
    if (type != "p") return "ERROR_INVALID_DOUBLE_POINTER";

    string actual_ptr = llDeleteSubString(raw, 0, 1);
    if (llSubStringIndex(actual_ptr, "mem_addr_") != 0) return "ERROR_INVALID_DOUBLE_POINTER";
    return actual_ptr;
}

integer WriteString(string ptr, string val) { return WriteRaw(ptr, "s:" + val); }
integer WriteInt(string ptr, integer val) { return WriteRaw(ptr, "i:" + (string)val); }
integer WriteFloat(string ptr, float val) { return WriteRaw(ptr, "f:" + (string)val); }
integer WritePointer(string ptr, string target) { return WriteRaw(ptr, "p:" + target); }
// ==============================================================================
// ARRAYS & POINTER MATH
// ==============================================================================
string EvaluateAddressOffset(string base_pointer, integer index)
{
    list parts = llParseString2List(base_pointer, ["_"], []);
    integer len = llGetListLength(parts);

    if (len < 3 || llList2String(parts, 0) != "mem" || llList2String(parts, 1) != "addr")
        return "ERROR_BAD_POINTER";

    string base = "mem_addr_" + llList2String(parts, 2);
    integer current_idx = 0;
    if (len == 4) current_idx = (integer)llList2String(parts, 3);

    return base + "_" + (string)(current_idx + index);
}
string AllocateArray(integer size, string type_prefix, string default_value)
{
    if (size <= 0) return "ERROR_INVALID_SIZE";

    string base_pointer = AllocateRaw("p", "ARRAY:" + (string)size);
    if (base_pointer == "ERROR_OUT_OF_MEMORY") return base_pointer;

    integer i;
    for (i = 0; i < size; i++)
    {
        string elem_ptr = base_pointer + "_" + (string)i;
        if (!llLinksetDataWrite(elem_ptr, type_prefix + ":" + default_value))
        {
            integer j;
            for (j = 0; j < i; j++) llLinksetDataDelete(base_pointer + "_" + (string)j);
            FreeMemory(base_pointer);
            return "ERROR_OUT_OF_MEMORY";
        }
        g_active_allocations++;
    }
    return base_pointer;
}
integer FreeArray(string base_pointer, integer size)
{
    if (llSubStringIndex(base_pointer, "mem_addr_") != 0) return FALSE;
    integer i;
    for (i = 0; i < size; i++) FreeMemory(EvaluateAddressOffset(base_pointer, i));
    return FreeMemory(base_pointer);
}
// ==============================================================================
// ADVANCED MEMORY OPERATIONS
// ==============================================================================
integer MemCopy(string dest_base, string src_base, integer elements)
{
    if (elements <= 0) return FALSE;

    list dest_parts = llParseString2List(dest_base, ["_"], []);
    list src_parts = llParseString2List(src_base, ["_"], []);

    integer dest_base_num = (integer)llList2String(dest_parts, 2);
    integer src_base_num = (integer)llList2String(src_parts, 2);

    integer dest_idx = 0;
    integer src_idx = 0;

    if (llGetListLength(dest_parts) == 4) dest_idx = (integer)llList2String(dest_parts, 3);
    if (llGetListLength(src_parts) == 4) src_idx = (integer)llList2String(src_parts, 3);

    integer reverse_copy = FALSE;
    if (dest_base_num == src_base_num && dest_idx > src_idx && dest_idx < (src_idx + elements))
    {
        reverse_copy = TRUE;
    }

    integer i;
    if (reverse_copy)
    {
        for (i = elements - 1; i >= 0; i--)
        {
            string src_addr = EvaluateAddressOffset(src_base, i);
            string dest_addr = EvaluateAddressOffset(dest_base, i);
            string val = ReadRaw(src_addr);

            if (val == "ERROR_NULL_POINTER") FreeMemory(dest_addr);
            else WriteRaw(dest_addr, val);
        }
    }
    else
    {
        for (i = 0; i < elements; i++)
        {
            string src_addr = EvaluateAddressOffset(src_base, i);
            string dest_addr = EvaluateAddressOffset(dest_base, i);
            string val = ReadRaw(src_addr);

            if (val == "ERROR_NULL_POINTER") FreeMemory(dest_addr);
            else WriteRaw(dest_addr, val);
        }
    }
    return TRUE;
}
integer MemSwap(string pointer_a, string pointer_b, integer elements)
{
    if (elements <= 0) return FALSE;
    integer i;
    for (i = 0; i < elements; i++)
    {
        string addr_a = EvaluateAddressOffset(pointer_a, i);
        string addr_b = EvaluateAddressOffset(pointer_b, i);
        string val_a = ReadRaw(addr_a);
        string val_b = ReadRaw(addr_b);

        if (val_a == "ERROR_NULL_POINTER" && val_b != "ERROR_NULL_POINTER")
        {
            WriteRaw(addr_a, val_b);
            FreeMemory(addr_b);
        }
        else if (val_b == "ERROR_NULL_POINTER" && val_a != "ERROR_NULL_POINTER")
        {
            WriteRaw(addr_b, val_a);
            FreeMemory(addr_a);
        }
        else if (val_a != "ERROR_NULL_POINTER" && val_b != "ERROR_NULL_POINTER")
        {
            WriteRaw(addr_a, val_b);
            WriteRaw(addr_b, val_a);
        }
    }
    return TRUE;
}
integer MemSet(string dest_base, string type_prefix, string value, integer elements)
{
    if (elements <= 0) return FALSE;
    integer i;
    for (i = 0; i < elements; i++)
    {
        WriteRaw(EvaluateAddressOffset(dest_base, i), type_prefix + ":" + value);
    }
    return TRUE;
}
integer MemCmp(string pointer_a, string pointer_b, integer elements)
{
    if (elements <= 0) return FALSE;
    integer i;
    for (i = 0; i < elements; i++)
    {
        string val_a = ReadRaw(EvaluateAddressOffset(pointer_a, i));
        string val_b = ReadRaw(EvaluateAddressOffset(pointer_b, i));

        if (val_a == "ERROR_NULL_POINTER" || val_b == "ERROR_NULL_POINTER") return FALSE;
        if (val_a != val_b) return FALSE;
    }
    return TRUE;
}
integer MemReverse(string base_pointer, integer elements)
{
    if (elements <= 1) return TRUE;
    integer i = 0;
    integer j = elements - 1;

    while (i < j)
    {
        MemSwap(EvaluateAddressOffset(base_pointer, i), EvaluateAddressOffset(base_pointer, j), 1);
        i++;
        j--;
    }
    return TRUE;
}
string ReallocArray(string old_base, integer old_size, integer new_size, string type_prefix, string default_value)
{
    if (old_size <= 0 || new_size <= 0) return "ERROR_INVALID_SIZE";
    string new_base = AllocateArray(new_size, type_prefix, default_value);
    if (new_base == "ERROR_INVALID_SIZE" || new_base == "ERROR_OUT_OF_MEMORY") return new_base;

    integer elements_to_copy = old_size;
    if (new_size < old_size) elements_to_copy = new_size;

    if (!MemCopy(new_base, old_base, elements_to_copy))
    {
        FreeArray(new_base, new_size);
        return "ERROR_MEMCOPY_FAIL";
    }

    FreeArray(old_base, old_size);
    return new_base;
}
// ==============================================================================
// DEFAULT STATE ENTRY
// ==============================================================================
default
{
    state_entry()
    {
    }
}
