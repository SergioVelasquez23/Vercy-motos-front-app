import React, { useState, useEffect } from 'react';
import { Product, CreateProductRequest, UpdateProductRequest } from '../models/Product';

interface Category {
  _id: string;
  nombre: string;
}

interface ProductFormProps {
  product?: Product;
  onSubmit: (productData: CreateProductRequest | UpdateProductRequest) => void;
  onCancel: () => void;
  isLoading?: boolean;
  isEdit?: boolean;
}

const ProductForm: React.FC<ProductFormProps> = ({
  product,
  onSubmit,
  onCancel,
  isLoading = false,
  isEdit = false
}) => {
  const [formData, setFormData] = useState<CreateProductRequest>({
    nombre: '',
    descripcion: '',
    precio: 0,
    costo: 0,
    categoria: '',
    imagenUrl: '',
    disponible: true,
    tipoProducto: 'individual',
    ingredientes: [],
    unidadMedida: '',
    stock: 0
  });

  const [errors, setErrors] = useState<{ [key: string]: string }>({});
  const [ingredientInput, setIngredientInput] = useState('');

  // Mock categories - replace with actual API call
  const categories: Category[] = [
    { _id: '688e56485b11ec6a26b76f9b', nombre: 'Licores' },
    { _id: 'cat_adicionales', nombre: 'Adicionales' },
    { _id: 'cat_bebidas_calientes', nombre: 'Bebidas calientes' },
    { _id: 'cat_bebidas_frias', nombre: 'Bebidas frias' },
    { _id: 'cat_cafe', nombre: 'Cafe' },
    { _id: 'cat_carnes', nombre: 'Carnes' },
    { _id: 'cat_especiales', nombre: 'Especiales' },
    { _id: 'cat_parrilla', nombre: 'Parrilla' }
  ];

  useEffect(() => {
    if (product && isEdit) {
      setFormData({
        nombre: product.nombre,
        descripcion: product.descripcion || '',
        precio: product.precio,
        costo: product.costo,
        categoria: product.categoria,
        imagenUrl: product.imagenUrl || '',
        disponible: product.disponible,
        tipoProducto: product.tipoProducto,
        ingredientes: product.ingredientes || [],
        unidadMedida: product.unidadMedida || '',
        stock: product.stock || 0
      });
    }
  }, [product, isEdit]);

  const validateForm = (): boolean => {
    const newErrors: { [key: string]: string } = {};

    if (!formData.nombre.trim()) {
      newErrors.nombre = 'El nombre es requerido';
    }

    if (formData.precio <= 0) {
      newErrors.precio = 'El precio debe ser mayor a 0';
    }

    if (formData.costo < 0) {
      newErrors.costo = 'El costo no puede ser negativo';
    }

    if (!formData.categoria) {
      newErrors.categoria = 'La categoría es requerida';
    }

    if (formData.stock !== undefined && formData.stock < 0) {
      newErrors.stock = 'El stock no puede ser negativo';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) {
      return;
    }

    const submitData = isEdit 
      ? { ...formData, _id: product!._id } as UpdateProductRequest
      : formData;

    onSubmit(submitData);
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target;
    
    setFormData(prev => ({
      ...prev,
      [name]: type === 'number' ? parseFloat(value) || 0 : 
               type === 'checkbox' ? (e.target as HTMLInputElement).checked : value
    }));

    // Clear error when user starts typing
    if (errors[name]) {
      setErrors(prev => ({ ...prev, [name]: '' }));
    }
  };

  const addIngredient = () => {
    if (ingredientInput.trim() && !formData.ingredientes?.includes(ingredientInput.trim())) {
      setFormData(prev => ({
        ...prev,
        ingredientes: [...(prev.ingredientes || []), ingredientInput.trim()]
      }));
      setIngredientInput('');
    }
  };

  const removeIngredient = (index: number) => {
    setFormData(prev => ({
      ...prev,
      ingredientes: prev.ingredientes?.filter((_, i) => i !== index) || []
    }));
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addIngredient();
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h2 className="text-2xl font-bold mb-6">
        {isEdit ? 'Editar Producto' : 'Agregar Nuevo Producto'}
      </h2>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Basic Information */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Nombre *
            </label>
            <input
              type="text"
              name="nombre"
              value={formData.nombre}
              onChange={handleInputChange}
              className={`w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                errors.nombre ? 'border-red-500' : 'border-gray-300'
              }`}
              placeholder="Nombre del producto"
            />
            {errors.nombre && <p className="text-red-500 text-sm mt-1">{errors.nombre}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Categoría *
            </label>
            <select
              name="categoria"
              value={formData.categoria}
              onChange={handleInputChange}
              className={`w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                errors.categoria ? 'border-red-500' : 'border-gray-300'
              }`}
            >
              <option value="">Seleccionar categoría</option>
              {categories.map((category) => (
                <option key={category._id} value={category._id}>
                  {category.nombre}
                </option>
              ))}
            </select>
            {errors.categoria && <p className="text-red-500 text-sm mt-1">{errors.categoria}</p>}
          </div>
        </div>

        {/* Description */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Descripción
          </label>
          <textarea
            name="descripcion"
            value={formData.descripcion}
            onChange={handleInputChange}
            rows={3}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Descripción del producto"
          />
        </div>

        {/* Pricing */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Precio *
            </label>
            <input
              type="number"
              name="precio"
              value={formData.precio}
              onChange={handleInputChange}
              min="0"
              step="0.01"
              className={`w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                errors.precio ? 'border-red-500' : 'border-gray-300'
              }`}
              placeholder="0.00"
            />
            {errors.precio && <p className="text-red-500 text-sm mt-1">{errors.precio}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Costo *
            </label>
            <input
              type="number"
              name="costo"
              value={formData.costo}
              onChange={handleInputChange}
              min="0"
              step="0.01"
              className={`w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                errors.costo ? 'border-red-500' : 'border-gray-300'
              }`}
              placeholder="0.00"
            />
            {errors.costo && <p className="text-red-500 text-sm mt-1">{errors.costo}</p>}
          </div>
        </div>

        {/* Product Type and Availability */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Tipo de producto
            </label>
            <select
              name="tipoProducto"
              value={formData.tipoProducto}
              onChange={handleInputChange}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="individual">Individual</option>
              <option value="combo">Combo</option>
              <option value="ingrediente">Ingrediente</option>
            </select>
          </div>

          <div className="flex items-center">
            <label className="flex items-center">
              <input
                type="checkbox"
                name="disponible"
                checked={formData.disponible}
                onChange={handleInputChange}
                className="mr-2 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <span className="text-sm font-medium text-gray-700">Disponible</span>
            </label>
          </div>
        </div>

        {/* Stock and Unit */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Stock
            </label>
            <input
              type="number"
              name="stock"
              value={formData.stock}
              onChange={handleInputChange}
              min="0"
              className={`w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                errors.stock ? 'border-red-500' : 'border-gray-300'
              }`}
              placeholder="0"
            />
            {errors.stock && <p className="text-red-500 text-sm mt-1">{errors.stock}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Unidad de medida
            </label>
            <input
              type="text"
              name="unidadMedida"
              value={formData.unidadMedida}
              onChange={handleInputChange}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="ej: kg, litros, unidades"
            />
          </div>
        </div>

        {/* Image URL */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            URL de imagen
          </label>
          <input
            type="url"
            name="imagenUrl"
            value={formData.imagenUrl}
            onChange={handleInputChange}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="https://ejemplo.com/imagen.jpg"
          />
        </div>

        {/* Ingredients (for combos) */}
        {formData.tipoProducto === 'combo' && (
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Ingredientes
            </label>
            <div className="flex mb-2">
              <input
                type="text"
                value={ingredientInput}
                onChange={(e) => setIngredientInput(e.target.value)}
                onKeyPress={handleKeyPress}
                className="flex-1 px-3 py-2 border border-gray-300 rounded-l-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Agregar ingrediente"
              />
              <button
                type="button"
                onClick={addIngredient}
                className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-r-md"
              >
                Agregar
              </button>
            </div>
            
            {formData.ingredientes && formData.ingredientes.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {formData.ingredientes.map((ingredient, index) => (
                  <span
                    key={index}
                    className="inline-flex items-center px-3 py-1 rounded-full text-sm bg-gray-100 text-gray-800"
                  >
                    {ingredient}
                    <button
                      type="button"
                      onClick={() => removeIngredient(index)}
                      className="ml-2 text-red-500 hover:text-red-700"
                    >
                      ×
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Form Actions */}
        <div className="flex justify-end space-x-4 pt-6">
          <button
            type="button"
            onClick={onCancel}
            className="px-6 py-2 text-gray-600 hover:text-gray-800"
            disabled={isLoading}
          >
            Cancelar
          </button>
          <button
            type="submit"
            disabled={isLoading}
            className="px-6 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg disabled:opacity-50"
          >
            {isLoading ? 'Guardando...' : isEdit ? 'Actualizar' : 'Crear'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default ProductForm;
