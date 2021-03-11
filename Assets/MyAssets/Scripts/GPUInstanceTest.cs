using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GPUInstanceTest : MonoBehaviour
{
    public int instanceAmount = 5000;
    public GameObject[] prefabs = null;
    public float radius = 50f;
    public bool randomColor = false;

    // Start is called before the first frame update
    void Start()
    {
        // new一个属性块对象，用来设置材质球属性
        MaterialPropertyBlock properties = new MaterialPropertyBlock();
        for (int i = 0; i < instanceAmount; i++)
        {
            Vector3 pos = Random.insideUnitSphere * radius + transform.position;
            GameObject instance = GameObject.Instantiate(prefabs[Random.Range(0, prefabs.Length)], pos, transform.rotation, transform);
            if (randomColor)
            {
                //instance.GetComponent<MeshRenderer>().material.color = new Color(Random.value, Random.value, Random.value); // 改颜色，这种方法会增加材质实例，材质球对象会变多

                // 用属性块的方式设置属性，不会产生新的材质对象，确保只有一个材质，不同的颜色通过PropertyBlock设置给材质
                // 启用GPUInstance的时候，材质里会有一个buffer，以instance id为索引储存所有不同的PropertyBlock
                // shader的pass里根据instance id从buffer获取到自己对象用的PropertyBlock进行渲染，所以只需一次修改材质状态(SetPass)就可以渲染多个对象
                // 没有启用GPUInstance的时候（或shader里没写支持buffer的代码），材质没有buffer，每渲染一个对象都会根据颜色修改一次材质（SetPass），来设置颜色，所以会产生很多SetPassCalls
                properties.SetColor("_Color", new Color(Random.value, Random.value, Random.value, Random.value));
                MeshRenderer render = instance.GetComponent<MeshRenderer>();
                if (render)
                {
                    render.SetPropertyBlock(properties);
                }
                else
                {
                    // 遍历子节点
                    foreach (Transform item in instance.transform)
                    {
                        render = item.GetComponent<MeshRenderer>();
                        if (render)
                        {
                            render.SetPropertyBlock(properties);
                        }
                    }
                }
            }
        }
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
