import com.ibm.icu.impl.coll.*;
import com.ibm.icu.util.CharsTrie;
import java.lang.reflect.Field;

public final class CollationDataBridge {
    public static CharsTrie.Iterator contextsIterator(CollationData data, int index) throws NoSuchFieldException, IllegalAccessException {
        Field field = CollationData.class.getDeclaredField("contexts");
        field.setAccessible(true);
        String contexts = (String)field.get(data);
        return CharsTrie.iterator(contexts, index + 2, 0);
    }
}
